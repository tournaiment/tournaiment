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
    AuditLog.log!(actor: nil, action: "match.started", auditable: @match)

    started_at = Time.current

    while @match.status == "running"
      break finalize!(:draw, "safety_cap") if safety_cap_reached?(started_at)

      color = next_color
      @current_color = color
      agent = color == "white" ? @match.white_agent : @match.black_agent

      move = request_move(agent, color)

      if move == "resign"
        return finalize!(color == "white" ? :black_win : :white_win, "resign")
      end

      begin
        @match.record_uci_move!(move)
      rescue ChessRules::IllegalMove, ChessRules::BadNotation, ChessRules::InvalidFen
        return finalize!(color == "white" ? :black_win : :white_win, "illegal_move")
      end

      if @match.result.present?
        return finalize_from_result!
      end
    end
  rescue AgentUnavailable
    loser_color = @current_color || next_color
    finalize!(loser_color == "white" ? :black_win : :white_win, "no_response")
  rescue StandardError => e
    @match.fail!
    AuditLog.log!(actor: nil, action: "match.failed", auditable: @match, metadata: { error: e.message })
    raise
  end

  private

  def safety_cap_reached?(started_at)
    @match.ply_count >= MAX_PLIES || Time.current - started_at >= MAX_WALL_CLOCK
  end

  def next_color
    @match.ply_count.even? ? "white" : "black"
  end

  def request_move(agent, color)
    payload = {
      match_id: @match.id,
      you_are: color,
      fen: @match.current_fen,
      move_number: (@match.ply_count / 2) + 1,
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
      @match.update!(result: "1-0", winner_color: "white", termination: termination)
    when :black_win
      @match.update!(result: "0-1", winner_color: "black", termination: termination)
    when :draw
      @match.update!(result: "1/2-1/2", winner_color: nil, termination: termination)
    end

    @match.finish!
    @match.update!(finished_at: Time.current)
    @match.generate_pgn!
    RatingService.new(@match).apply!
    AuditLog.log!(actor: nil, action: "match.finished", auditable: @match, metadata: { result: @match.result, termination: termination })
  end

  def finalize_from_result!
    case @match.result
    when "1-0"
      finalize!(:white_win, "checkmate")
    when "0-1"
      finalize!(:black_win, "checkmate")
    when "1/2-1/2"
      finalize!(:draw, "draw")
    else
      finalize!(:draw, "draw")
    end
  end
end
