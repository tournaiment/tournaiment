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
    @clock = MatchClock.new(@match)
    @clock.ensure_initialized!
    @match.snapshot_agent_models!
    AuditLog.log!(actor: nil, action: "match.started", auditable: @match)

    started_at = Time.current

    while @match.status == "running"
      break finalize!(:draw, "safety_cap") if safety_cap_reached?(started_at)

      actor = next_actor
      @current_actor = actor
      agent = @match.agent_for_actor(actor)

      turn_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      move = nil
      begin
        move = request_move(agent, actor)
      rescue AgentUnavailable
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - turn_started
        if @clock.consume!(actor, elapsed) == :time_loss
          return finalize!(winner_actor: opponent_for_actor(actor), termination: "time_loss", actor: actor)
        end
        raise
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - turn_started
      if @clock.consume!(actor, elapsed) == :time_loss
        return finalize!(winner_actor: opponent_for_actor(actor), termination: "time_loss", actor: actor)
      end

      if move == "resign"
        return finalize!(winner_actor: opponent_for_actor(actor), termination: "resign", actor: actor)
      end

      begin
        @match.record_move!(move)
      rescue ChessRules::IllegalMove, ChessRules::BadNotation, ChessRules::InvalidFen, GoRules::IllegalMove
        return finalize!(winner_actor: opponent_for_actor(actor), termination: "illegal_move", actor: actor)
      end

      if @match.result.present?
        return finalize_from_result!
      end
    end
  rescue AgentUnavailable
    loser_actor = @current_actor || next_actor
    finalize!(winner_actor: opponent_for_actor(loser_actor), termination: "no_response", actor: loser_actor)
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
      time_remaining_seconds: @clock.time_remaining_seconds(actor),
      rated: @match.rated,
      tournament_id: @match.tournament_id,
      opponent_agent_id: opponent_for(actor)&.id,
      opponent_name: opponent_for(actor)&.name,
      time_control: time_control_payload,
      time_control_state: {
        self: @clock.actor_state(actor),
        opponent: @clock.actor_state(opponent_for_actor(actor))
      }
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

  def opponent_for(actor)
    rules = GameRegistry.fetch!(@match.game_key)
    if actor == rules.actors.first
      @match.agent_b
    else
      @match.agent_a
    end
  end

  def opponent_for_actor(actor)
    rules = GameRegistry.fetch!(@match.game_key)
    return rules.actors.second if actor == rules.actors.first
    rules.actors.first
  end

  def time_control_payload
    preset = @match.time_control_preset
    if preset
      {
        preset_id: preset.key,
        category: preset.category,
        clock_type: preset.clock_type,
        clock_config: preset.clock_config
      }
    else
      { category: @match.time_control }.compact
    end
  end

  def finalize!(winner_actor:, termination:, actor: nil)
    if winner_actor.nil?
      @match.update!(result: "1/2-1/2", winner_side: nil, termination: termination)
    else
      result = result_for_winner_actor(winner_actor)
      @match.update!(result: result, winner_side: side_for_actor(winner_actor), termination: termination)
    end

    apply_outcome_metadata(termination, winner_actor, actor)
    @match.finish!
    @match.update!(finished_at: Time.current)
    @match.generate_record!
    RatingService.new(@match).apply!
    AuditLog.log!(actor: nil, action: "match.finished", auditable: @match, metadata: { result: @match.result, termination: termination })
  end

  def finalize_from_result!
    rules = GameRegistry.fetch!(@match.game_key)
    scores = rules.scores_for_result(@match.result)
    first_actor = rules.actors.first
    second_actor = rules.actors.second
    first_score = scores.fetch(first_actor, 0.0)
    second_score = scores.fetch(second_actor, 0.0)

    if first_score > second_score
      finalize!(winner_actor: first_actor, termination: rules.termination_for_result(@match.result))
    elsif second_score > first_score
      finalize!(winner_actor: second_actor, termination: rules.termination_for_result(@match.result))
    else
      finalize!(winner_actor: nil, termination: rules.termination_for_result(@match.result))
    end
  end

  def apply_outcome_metadata(termination, winner_actor, actor)
    if termination == "resign" && actor
      @match.update!(resigned_by_side: side_for_actor(actor))
      return
    end

    if %w[illegal_move no_response time_loss].include?(termination) && actor
      @match.update!(forfeit_by_side: side_for_actor(actor))
      return
    end

    if winner_actor.nil?
      @match.update!(draw_reason: termination)
    end
  end

  def result_for_winner_actor(winner_actor)
    rules = GameRegistry.fetch!(@match.game_key)
    loser_actor = opponent_for_actor(winner_actor)

    [
      "1-0",
      "0-1"
    ].each do |result|
      scores = rules.scores_for_result(result)
      return result if scores.fetch(winner_actor, 0.0) > scores.fetch(loser_actor, 0.0)
    end

    winner_actor == "white" ? "1-0" : "0-1"
  end

  def side_for_actor(actor)
    rules = GameRegistry.fetch!(@match.game_key)
    return "a" if actor == rules.actors.first
    return "b" if actor == rules.actors.second

    nil
  end
end
