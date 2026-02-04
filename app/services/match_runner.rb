require "net/http"
require "json"

class MatchRunner
  class AgentUnavailable < StandardError; end

  MAX_PLIES = 500
  MAX_WALL_CLOCK = 20.minutes
  AGENT_TIMEOUT = 5.seconds

  def initialize(match)
    @match = match
  end

  def run!
    return unless @match.status == "queued"

    @match.start!
    @match.update!(started_at: Time.current) if @match.started_at.nil?
    @match.snapshot_agent_models!
    AuditLog.log!(actor: nil, action: "match.started", auditable: @match)

    started_at = Time.current

    while @match.status == "running"
      break finalize!(:draw, "safety_cap") if safety_cap_reached?(started_at)

      actor = next_actor
      @current_actor = actor
      agent = @match.agent_for_actor(actor)

      move = request_move(agent, actor)

      if move == "resign"
        return finalize!(actor == "white" ? :black_win : :white_win, "resign")
      end

      begin
        @match.record_move!(move)
      rescue ChessRules::IllegalMove, ChessRules::BadNotation, ChessRules::InvalidFen, GoRules::IllegalMove
        return finalize!(actor == "white" ? :black_win : :white_win, "illegal_move")
      end

      if @match.result.present?
        return finalize_from_result!
      end
    end
  rescue AgentUnavailable
    loser_actor = @current_actor || next_actor
    finalize!(loser_actor == "white" ? :black_win : :white_win, "no_response")
  rescue StandardError => e
    @match.fail!
    AuditLog.log!(actor: nil, action: "match.failed", auditable: @match, metadata: { error: e.message })
    raise
  end

  private

  def safety_cap_reached?(started_at)
    @match.ply_count >= MAX_PLIES || Time.current - started_at >= MAX_WALL_CLOCK
  end

  def next_actor
    GameRegistry.fetch!(@match.game_key).actor_for_ply(@match.ply_count)
  end

  def request_move(agent, actor)
    rules = GameRegistry.fetch!(@match.game_key)
    payload = {
      match_id: @match.id,
      game: @match.game_key,
      you_are: actor,
      state: @match.current_state,
      turn_number: rules.turn_number_for_ply(@match.ply_count + 1),
      time_remaining_seconds: 0
    }

    endpoint = agent.metadata["move_endpoint"].to_s
    raise AgentUnavailable, "Agent move endpoint missing" if endpoint.empty?

    uri = URI.parse(endpoint)
    response = nil

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: AGENT_TIMEOUT, read_timeout: AGENT_TIMEOUT) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      response = http.request(request)
    end

    if response.nil? || response.code.to_i >= 400
      raise AgentUnavailable, "Agent request failed"
    end

    body = JSON.parse(response.body)
    move = body.fetch("move", "").to_s
    raise AgentUnavailable, "Agent move missing" if move.empty?
    move
  rescue JSON::ParserError, SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise AgentUnavailable, e.message
  end

  def finalize!(outcome, termination)
    case outcome
    when :white_win
      @match.update!(result: "1-0", winner_side: "a", termination: termination)
    when :black_win
      @match.update!(result: "0-1", winner_side: "b", termination: termination)
    when :draw
      @match.update!(result: "1/2-1/2", winner_side: nil, termination: termination)
    end

    @match.finish!
    @match.update!(finished_at: Time.current)
    @match.generate_record!
    RatingService.new(@match).apply!
    AuditLog.log!(actor: nil, action: "match.finished", auditable: @match, metadata: { result: @match.result, termination: termination })
  end

  def finalize_from_result!
    rules = GameRegistry.fetch!(@match.game_key)
    scores = rules.scores_for_result(@match.result)
    white_score = scores.fetch("white", 0.0)
    black_score = scores.fetch("black", 0.0)

    if white_score > black_score
      finalize!(:white_win, rules.termination_for_result(@match.result))
    elsif black_score > white_score
      finalize!(:black_win, rules.termination_for_result(@match.result))
    else
      finalize!(:draw, rules.termination_for_result(@match.result))
    end
  end
end
