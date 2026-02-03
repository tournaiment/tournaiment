#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

module DemoSeed
  AGENT_NAMES = [
    "NeonRook",
    "QuantumBishop",
    "CipherKnight",
    "PlasmaQueen",
    "VoidPawn",
    "SignalLancer",
    "VectorMonk",
    "ArcStorm",
    "EchoForge",
    "PulseArray",
    "SpecterLine",
    "NovaGrid"
  ].freeze

  OPENINGS = [
    %w[e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6],
    %w[d2d4 d7d5 c2c4 e7e6 b1c3 g8f6],
    %w[c2c4 e7e5 b1c3 g8f6 g2g3 d7d5],
    %w[e2e4 c7c5 g1f3 d7d6 d2d4 c5d4],
    %w[g1f3 d7d5 g2g3 c7c6 f1g2 g8f6]
  ].freeze

  GO_OPENINGS_19 = [
    %w[D4 Q16 D16 Q4 C4 R16 pass pass],
    %w[Q4 D16 Q16 D4 R4 C16 pass pass],
    %w[C3 D4 Q3 Q4 R4 D16 pass pass],
    %w[D10 Q10 C4 R16 D4 Q16],
    %w[K10 D10 Q10 C3 R3 D4]
  ].freeze

  GO_OPENINGS_13 = [
    %w[D4 J10 D10 J4 C4 K10 pass pass],
    %w[J4 D10 J10 D4 K4 C10 pass pass],
    %w[C3 D4 J3 J4 K4 D10 pass pass],
    %w[G7 D7 J7 C3 K3 D4],
    %w[H4 D4 J4 C10 K10 D10]
  ].freeze

  GO_OPENINGS_9 = [
    %w[D4 F6 D6 F4 C4 G6 pass pass],
    %w[F4 D6 F6 D4 G4 C6 pass pass],
    %w[C3 D4 F3 F4 G4 D6 pass pass],
    %w[E5 C5 G5 C3 G3 C4],
    %w[D3 E4 F5 C6 G6 D6]
  ].freeze

  RESULTS = ["1-0", "0-1", "1/2-1/2"].freeze

  TIME_CONTROLS = ["bullet", "blitz", "rapid", "classical"].freeze

  MODEL_POOL = [
    { provider: "openai", model_name: "gpt-4.1", model_version: "2025-11-15" },
    { provider: "openai", model_name: "gpt-4.1-mini", model_version: "2025-11-15" },
    { provider: "openai", model_name: "gpt-4o", model_version: "2025-09-01" },
    { provider: "openai", model_name: "o4-mini", model_version: "2025-07-10" },
    { provider: "anthropic", model_name: "claude-3.5-sonnet", model_version: "2025-10-20" },
    { provider: "anthropic", model_name: "claude-3.5-haiku", model_version: "2025-10-20" },
    { provider: "google", model_name: "gemini-1.5-pro", model_version: "2025-08-01" },
    { provider: "google", model_name: "gemini-1.5-flash", model_version: "2025-08-01" },
    { provider: "mistral", model_name: "mistral-large", model_version: "2025-06-12" },
    { provider: "mistral", model_name: "mistral-small", model_version: "2025-06-12" },
    { provider: "meta", model_name: "llama-3.2-70b", model_version: "2025-05-05" },
    { provider: "meta", model_name: "llama-3.2-8b", model_version: "2025-05-05" },
    { provider: "deepseek", model_name: "deepseek-r1", model_version: "2025-02-01" },
    { provider: "cohere", model_name: "command-r+", model_version: "2025-03-20" },
    { provider: "openclaw", model_name: "claw-alpha", model_version: "1.0.0" },
    { provider: "openclaw", model_name: "claw-beta", model_version: "1.1.0" },
    { provider: "openclaw", model_name: "claw-gamma", model_version: "2.0.0" },
    { provider: "openclaw", model_name: "claw-delta", model_version: "2.2.0" },
    { provider: "openclaw", model_name: "claw-epsilon", model_version: "3.0.0" }
  ].freeze

  module_function

  def run!
    if ENV["SEED_DEMO_FORCE"] == "1"
      MatchAgentModel.delete_all
      Move.delete_all
      RatingChange.delete_all
      Match.delete_all
      Rating.delete_all
      TournamentEntry.delete_all
      Tournament.delete_all
      TournamentInterest.delete_all
      AuditLog.delete_all
    end

    seed_agents
    seed_matches if Match.count.zero?
  end

  def seed_agents
    AGENT_NAMES.each_with_index do |name, idx|
      agent = Agent.find_or_initialize_by(name: name)
      next unless agent.new_record?

      model = MODEL_POOL[idx % MODEL_POOL.length]
      agent.description = "Demo agent ##{idx + 1}"
      agent.metadata = {
        move_endpoint: "https://example.com/agents/#{name.downcase}/move",
        models: {
          "chess" => {
            provider: model[:provider],
            model_name: model[:model_name],
            model_version: model[:model_version],
            model_info: { seed: "demo", tier: "standard" }
          }
        }
      }
      raw_key = Agent.generate_api_key
      agent.api_key = raw_key
      agent.api_key_hash = Agent.api_key_hash(raw_key)
      agent.api_key_last_rotated_at = Time.current
      agent.save!
      AuditLog.log!(actor: nil, action: "agent.seeded", auditable: agent)
    end
  end

  def seed_matches
    agents = Agent.order(:created_at).limit(AGENT_NAMES.length).to_a
    return if agents.length < 2
    target = (ENV["SEED_MATCHES"] || "1000").to_i
    finished_cutoff = (target * 0.85).to_i

    target.times do |i|
      white = agents.sample
      black = (agents - [white]).sample
      game_key = ["chess", "go"].sample
      game_config = if game_key == "go"
        { "board_size" => [9, 13, 19].sample, "ruleset" => "chinese" }
      else
        {}
      end

      match = Match.create!(
        white_agent: white,
        black_agent: black,
        rated: true,
        time_control: TIME_CONTROLS.sample,
        status: "running",
        game_key: game_key,
        game_config: game_config
      )

      match.snapshot_agent_models!

      if game_key == "go"
        result = apply_go_opening(match, go_opening_for_size(game_config["board_size"]))
      else
        apply_opening(match, OPENINGS.sample)
        result = nil
      end

      if i < finished_cutoff
        result ||= RESULTS.sample
        finalize_match(match, result)
      else
        match.update!(status: "running", started_at: match.started_at || Time.current)
      end
    end
  end

  def go_opening_for_size(size)
    case size.to_i
    when 9
      GO_OPENINGS_9.sample
    when 13
      GO_OPENINGS_13.sample
    else
      GO_OPENINGS_19.sample
    end
  end

  def apply_opening(match, moves)
    state = match.initial_state
    moves.each_with_index do |uci, idx|
      actor = ChessRules.actor_for_ply(idx)
      data = ChessRules.apply_move(state: state, move: uci, actor: actor)
      state = data[:state]
      ply = idx + 1
      move_number = ChessRules.turn_number_for_ply(ply)

      Move.create!(
        match: match,
        ply: ply,
        move_number: move_number,
        actor: actor,
        notation: uci,
        display: data[:display],
        state: data[:state],
        color: actor,
        uci: uci,
        san: data[:display],
        fen: data[:state]
      )
    end

    match.update!(
      current_state: state,
      current_fen: state,
      ply_count: moves.length,
      started_at: match.started_at || Time.current
    )
  end

  def apply_go_opening(match, moves)
    state = match.initial_state
    result = nil
    status = "running"

    moves.each_with_index do |move, idx|
      actor = GoRules.actor_for_ply(idx)
      data = GoRules.apply_move(state: state, move: move, actor: actor)
      state = data[:state]
      ply = idx + 1
      move_number = GoRules.turn_number_for_ply(ply)

      Move.create!(
        match: match,
        ply: ply,
        move_number: move_number,
        actor: actor,
        notation: move,
        display: data[:display],
        state: data[:state],
        color: actor,
        uci: move,
        san: data[:display],
        fen: data[:state]
      )

      status = data[:status] || status
      result = data[:result] if data[:result].present?
    end

    match.update!(
      current_state: state,
      current_fen: state,
      ply_count: moves.length,
      started_at: match.started_at || Time.current
    )

    result
  end

  def finalize_match(match, result)
    rules = GameRegistry.fetch!(match.game_key)
    termination = rules.termination_for_result(result)
    scores = rules.scores_for_result(result)
    winner_actor = if scores["white"] > scores["black"]
                     "white"
                   elsif scores["black"] > scores["white"]
                     "black"
                   else
                     nil
                   end

    match.update!(
      status: "finished",
      result: result,
      termination: termination,
      finished_at: Time.current,
      winner_actor: winner_actor,
      winner_color: winner_actor
    )

    moves = match.moves.order(:ply).pluck(:display)
    match.update!(pgn: rules.render_record(moves: moves, result: result, tags: match.send(:default_tags)))
    RatingService.new(match).apply!
  end
end

DemoSeed.run!
