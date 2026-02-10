#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

module DemoSeed
  BASE_AGENT_NAMES = [
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

  AGENT_PREFIXES = %w[
    Neon Quantum Cipher Plasma Void Signal Vector Arc Echo Specter Nova
    Flux Drift Lumen Apex Orbit Pulse Vanta Aurora Helix Ion
  ].freeze

  AGENT_SUFFIXES = %w[
    Rook Bishop Knight Queen Pawn Lancer Monk Array Forge Grid Line
    Circuit Anchor Prism Relay Bastion Rift Spark Sentinel Weave
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

  RESULTS = [ "1-0", "0-1", "1/2-1/2" ].freeze

  TIME_CONTROLS = [ "bullet", "blitz", "rapid", "classical" ].freeze

  DEMO_TOURNAMENT_NAMES = {
    planned: "Demo Planning Cup",
    open_registration: "Demo Open Registration League",
    open_cash_prize: "Demo Cash Prize Open",
    live_knockout: "Demo Live Knockout",
    live_round_robin: "Demo Live Round Robin",
    live_cash_prize: "Demo Cash Prize Showdown",
    finished_knockout: "Demo Finished Knockout",
    finished_round_robin: "Demo Finished Round Robin",
    finished_cash_prize: "Demo Cash Prize Classic",
    cancelled: "Demo Cancelled Invitational",
    invalid: "Demo Invalidated Cash Prize Cup"
  }.freeze

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
      safe_delete_all(MatchAgentModel)
      safe_delete_all(Move)
      safe_delete_all(RatingChange)
      safe_delete_all(MatchRequest)
      safe_delete_all(Match)
      safe_delete_all(TournamentPairing)
      safe_delete_all(TournamentRound)
      safe_delete_all(TournamentTimeControlPreset)
      safe_delete_all(Rating)
      safe_delete_all(TournamentEntry)
      safe_delete_all(Tournament)
      safe_delete_all(TournamentInterest)
      safe_delete_all(AuditLog)
    end

    ensure_time_control_presets!
    seed_agents
    seed_matches if Match.count.zero?
    seed_tournaments
  end

  def safe_delete_all(model)
    return unless model.table_exists?

    model.delete_all
  end

  def ensure_time_control_presets!
    presets = [
      {
        key: "chess_bullet_1p0",
        game_key: "chess",
        category: "bullet",
        clock_type: "increment",
        clock_config: { base_seconds: 60, increment_seconds: 0 },
        rated_allowed: true
      },
      {
        key: "chess_blitz_3p2",
        game_key: "chess",
        category: "blitz",
        clock_type: "increment",
        clock_config: { base_seconds: 180, increment_seconds: 2 },
        rated_allowed: true
      },
      {
        key: "chess_rapid_10p0",
        game_key: "chess",
        category: "rapid",
        clock_type: "increment",
        clock_config: { base_seconds: 600, increment_seconds: 0 },
        rated_allowed: true
      },
      {
        key: "chess_classical_30p0",
        game_key: "chess",
        category: "classical",
        clock_type: "increment",
        clock_config: { base_seconds: 1800, increment_seconds: 0 },
        rated_allowed: true
      },
      {
        key: "go_rapid_10m_5x30",
        game_key: "go",
        category: "rapid",
        clock_type: "byoyomi",
        clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
        rated_allowed: true
      }
    ]

    presets.each do |attrs|
      preset = TimeControlPreset.find_or_initialize_by(key: attrs[:key])
      preset.assign_attributes(attrs)
      preset.save!
    end
  end

  def seed_agents
    agent_names.each_with_index do |name, idx|
      agent = Agent.find_or_initialize_by(name: name)

      model = MODEL_POOL[idx % MODEL_POOL.length]
      agent.description ||= "Demo agent ##{idx + 1}"
      agent.metadata ||= {}
      agent.metadata["move_endpoint"] ||= "https://example.com/agents/#{name.downcase}/move"
      agent.metadata["models"] ||= {}
      agent.metadata["models"]["chess"] ||= {
        "provider" => model[:provider],
        "model_name" => model[:model_name],
        "model_version" => model[:model_version],
        "model_info" => { "seed" => "demo", "tier" => "standard" }
      }
      agent.metadata["models"]["go"] ||= agent.metadata["models"]["chess"]

      if agent.new_record?
        raw_key = Agent.generate_api_key
        agent.api_key = raw_key
        agent.api_key_hash = Agent.api_key_hash(raw_key)
        agent.api_key_last_rotated_at = Time.current
      end

      agent.save!
      AuditLog.log!(actor: nil, action: "agent.seeded", auditable: agent) if agent.previous_changes.key?("id")
    end

    backdate_agents if ENV["SEED_BACKDATE"] != "0"
  end

  def seed_matches
    agents = Agent.where(name: agent_names).order(:created_at).to_a
    return if agents.length < 2
    target = (ENV["SEED_MATCHES"] || "1000").to_i
    finished_cutoff = (target * 0.85).to_i
    chess_games = load_chess_pgn_games
    go_games = load_go_sgf_games
    real_ratio = (ENV["SEED_REAL_GAMES_RATIO"] || "0.45").to_f.clamp(0.0, 1.0)

    target.times do |i|
      white = agents.sample
      black = (agents - [ white ]).sample
      game_key = [ "chess", "go" ].sample
      preset = random_rated_preset_for(game_key)
      rated = preset.present?
      time_control = preset&.category || TIME_CONTROLS.sample
      use_real = rand < real_ratio
      if game_key == "go" && use_real && go_games.any?
        game_config = { "board_size" => go_games.sample[:size], "ruleset" => "chinese" }
      elsif game_key == "go"
        game_config = { "board_size" => [ 9, 13, 19 ].sample, "ruleset" => "chinese" }
      else
        game_config = {}
      end

      match_created_at = random_past_time
      started_at = match_created_at + rand(2..90).minutes
      finished_at = started_at + rand(5..120).minutes

      match = Match.create!(
        agent_a: white,
        agent_b: black,
        rated: rated,
        time_control: time_control,
        time_control_preset: preset,
        status: "running",
        game_key: game_key,
        game_config: game_config,
        created_at: match_created_at,
        updated_at: match_created_at
      )

      match.snapshot_agent_models!

      if game_key == "go"
        if use_real && go_games.any?
          game = go_games.sample
          match.update_columns(
            game_config: match.game_config.merge("board_size" => game[:size]),
            updated_at: Time.current
          )
          begin
            result = apply_go_moves(match, game[:moves])
            result ||= game[:result]
          rescue GoRules::IllegalMove
            reset_match_state!(match)
            result = apply_go_opening(match, go_opening_for_size(game_config["board_size"]))
          end
        else
          result = apply_go_opening(match, go_opening_for_size(game_config["board_size"]))
        end
      else
        if use_real && chess_games.any?
          game = chess_games.sample
          begin
            result = apply_chess_moves(match, game[:moves])
            result ||= game[:result]
          rescue StandardError
            reset_match_state!(match)
            apply_opening(match, OPENINGS.sample)
            result = nil
          end
        else
          apply_opening(match, OPENINGS.sample)
          result = nil
        end
      end

      if i < finished_cutoff
        result ||= RESULTS.sample
        finalize_match(match, result, started_at: started_at, finished_at: finished_at)
      else
        match.update_columns(status: "running", started_at: started_at, updated_at: started_at)
      end
    end
  end

  def random_rated_preset_for(game_key)
    presets = TimeControlPreset.active.where(game_key: game_key, rated_allowed: true).to_a
    return nil if presets.empty?

    presets.sample
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
    apply_chess_moves(match, moves)
  end

  def apply_go_opening(match, moves)
    state = match.initial_state
    result = nil

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
        fen: data[:state],
        created_at: match.created_at + (idx + 1).minutes
      )

      result = data[:result] if data[:result].present?
    end

    match.update_columns(
      current_state: state,
      current_fen: state,
      ply_count: moves.length,
      started_at: match.started_at || match.created_at,
      updated_at: Time.current
    )

    result
  end

  def apply_chess_moves(match, moves)
    state = match.initial_state
    result = nil
    status = "running"

    moves.each_with_index do |move, idx|
      actor = ChessRules.actor_for_ply(idx)
      data = ChessRules.apply_move(state: state, move: move, actor: actor)
      state = data[:state]
      ply = idx + 1
      move_number = ChessRules.turn_number_for_ply(ply)

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
        fen: data[:state],
        created_at: match.created_at + (idx + 1).minutes
      )

      status = data[:status] || status
      result = data[:result] if data[:result].present?
    end

    match.update_columns(
      current_state: state,
      current_fen: state,
      ply_count: moves.length,
      started_at: match.started_at || match.created_at,
      updated_at: Time.current
    )

    result
  end

  def apply_go_moves(match, moves)
    state = match.initial_state
    result = nil

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
        fen: data[:state],
        created_at: match.created_at + (idx + 1).minutes
      )

      result = data[:result] if data[:result].present?
    end

    match.update!(
      current_state: state,
      current_fen: state,
      ply_count: moves.length,
      started_at: match.started_at || match.created_at
    )

    result
  end

  def finalize_match(match, result, started_at: nil, finished_at: nil)
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

    attrs = {
      status: "finished",
      result: result,
      termination: termination,
      started_at: started_at || match.started_at,
      finished_at: finished_at || Time.current
    }
    if match.respond_to?(:winner_side=)
      attrs[:winner_side] = winner_actor
    elsif match.respond_to?(:winner_actor=)
      attrs[:winner_actor] = winner_actor
    end
    if match.respond_to?(:winner_color=)
      attrs[:winner_color] = winner_actor
    end

    match.update!(attrs)

    moves = match.moves.order(:ply).pluck(:display)
    match.update!(pgn: rules.render_record(moves: moves, result: result, tags: match.send(:default_tags)))
    RatingService.new(match).apply!

    if finished_at
      RatingChange.where(match_id: match.id).update_all(created_at: finished_at)
      match.update_columns(updated_at: finished_at)
    end
  end

  def seed_tournaments
    agents = Agent.where(name: agent_names).order(:created_at).to_a
    return if agents.length < 8

    seed_planned_tournament(agents)
    seed_open_registration_tournament(agents)
    seed_open_cash_prize_tournament(agents)
    seed_live_knockout_tournament(agents)
    seed_live_round_robin_tournament(agents)
    seed_live_cash_prize_tournament(agents)
    seed_finished_knockout_tournament(agents)
    seed_finished_round_robin_tournament(agents)
    seed_finished_cash_prize_tournament(agents)
    seed_cancelled_tournament(agents)
    seed_invalid_tournament(agents)
  end

  def build_demo_tournament!(key, attrs, allowed_preset_keys:, locked_preset_key: nil)
    tournament = Tournament.find_or_initialize_by(name: DEMO_TOURNAMENT_NAMES.fetch(key))
    tournament.assign_attributes(attrs)
    tournament.save!
    sync_tournament_presets!(tournament, allowed_keys: allowed_preset_keys, locked_key: locked_preset_key)
    tournament
  end

  def sync_tournament_presets!(tournament, allowed_keys:, locked_key:)
    keys = Array(allowed_keys).map(&:to_s).uniq
    if locked_key.present? && !keys.include?(locked_key)
      keys << locked_key
    end

    presets_by_key = TimeControlPreset.active.where(key: keys).index_by(&:key)
    missing = keys - presets_by_key.keys
    if missing.any?
      raise ArgumentError, "Missing demo preset(s): #{missing.join(', ')}"
    end

    locked_id = locked_key.present? ? presets_by_key.fetch(locked_key).id : nil
    preset_ids = keys.map { |preset_key| presets_by_key.fetch(preset_key).id }

    Tournament.transaction do
      tournament.update!(locked_time_control_preset_id: locked_id)

      if preset_ids.empty?
        tournament.tournament_time_control_presets.delete_all
      else
        tournament.tournament_time_control_presets.where.not(time_control_preset_id: preset_ids).delete_all
        preset_ids.each do |preset_id|
          tournament.tournament_time_control_presets.find_or_create_by!(time_control_preset_id: preset_id)
        end
      end
    end
  end

  def seed_planned_tournament(agents)
    tournament = build_demo_tournament!(
      :planned,
      {
        description: "Created but not scheduled yet. Useful for empty-state UI.",
        status: "created",
        format: "single_elimination",
        game_key: "chess",
        time_control: "classical",
        rated: true,
        monied: false,
        max_players: 16,
        starts_at: 7.days.from_now,
        ends_at: nil
      },
      allowed_preset_keys: %w[chess_classical_30p0 chess_rapid_10p0],
      locked_preset_key: "chess_classical_30p0"
    )
    return if tournament.tournament_entries.exists?

    ensure_entries!(tournament, agents.first(4))
  end

  def seed_open_registration_tournament(agents)
    tournament = build_demo_tournament!(
      :open_registration,
      {
        description: "Registration is open. No pairings generated yet.",
        status: "registration_open",
        format: "round_robin",
        game_key: "go",
        time_control: "rapid",
        rated: false,
        monied: false,
        max_players: 12,
        starts_at: 2.days.from_now,
        ends_at: nil
      },
      allowed_preset_keys: %w[go_rapid_10m_5x30],
      locked_preset_key: nil
    )
    return if tournament.tournament_entries.exists?

    ensure_entries!(tournament, agents.first(6))
  end

  def seed_open_cash_prize_tournament(agents)
    tournament = build_demo_tournament!(
      :open_cash_prize,
      {
        description: "Cash prize bracket with registration currently open.",
        status: "registration_open",
        format: "single_elimination",
        game_key: "chess",
        time_control: "blitz",
        rated: true,
        monied: true,
        max_players: 16,
        starts_at: 18.hours.from_now,
        ends_at: nil
      },
      allowed_preset_keys: %w[chess_blitz_3p2],
      locked_preset_key: "chess_blitz_3p2"
    )
    return if tournament.tournament_entries.exists?

    ensure_entries!(tournament, agents.rotate(3).first(8))
  end

  def seed_live_knockout_tournament(agents)
    tournament = build_demo_tournament!(
      :live_knockout,
      {
        description: "Single elimination bracket currently in progress.",
        status: "running",
        format: "single_elimination",
        game_key: "chess",
        time_control: "rapid",
        rated: false,
        monied: false,
        max_players: 8,
        starts_at: 1.day.ago,
        ends_at: nil
      },
      allowed_preset_keys: %w[chess_rapid_10p0],
      locked_preset_key: "chess_rapid_10p0"
    )
    return if tournament.tournament_rounds.exists?

    players = agents.first(8)
    ensure_entries!(tournament, players)

    round = tournament.tournament_rounds.create!(round_number: 1, status: "running", started_at: 6.hours.ago)

    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 1,
      agent_a: players[0],
      agent_b: players[7],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 5.hours.ago,
      finished_at: 4.hours.ago
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 2,
      agent_a: players[3],
      agent_b: players[4],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 5.hours.ago,
      finished_at: 4.hours.ago
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 3,
      agent_a: players[1],
      agent_b: players[6],
      pairing_status: "running",
      match_status: "running",
      started_at: 1.hour.ago
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 4,
      agent_a: players[2],
      agent_b: players[5],
      pairing_status: "running",
      match_status: "queued"
    )
  end

  def seed_live_round_robin_tournament(agents)
    tournament = build_demo_tournament!(
      :live_round_robin,
      {
        description: "Round robin league with active and upcoming rounds.",
        status: "running",
        format: "round_robin",
        game_key: "go",
        time_control: "rapid",
        rated: false,
        monied: false,
        max_players: 4,
        starts_at: 3.days.ago,
        ends_at: nil
      },
      allowed_preset_keys: %w[go_rapid_10m_5x30],
      locked_preset_key: "go_rapid_10m_5x30"
    )
    return if tournament.tournament_rounds.exists?

    players = agents.last(4)
    ensure_entries!(tournament, players)

    round1 = tournament.tournament_rounds.create!(round_number: 1, status: "finished", started_at: 3.days.ago, finished_at: 2.days.ago)
    round2 = tournament.tournament_rounds.create!(round_number: 2, status: "running", started_at: 1.day.ago)
    round3 = tournament.tournament_rounds.create!(round_number: 3, status: "pending")

    create_pairing_with_match!(
      tournament: tournament,
      round: round1,
      slot: 1,
      agent_a: players[0],
      agent_b: players[1],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 3.days.ago + 1.hour,
      finished_at: 3.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round1,
      slot: 2,
      agent_a: players[2],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "1/2-1/2",
      started_at: 3.days.ago + 1.hour,
      finished_at: 3.days.ago + 2.hours
    )

    create_pairing_with_match!(
      tournament: tournament,
      round: round2,
      slot: 1,
      agent_a: players[0],
      agent_b: players[2],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 1.day.ago + 1.hour,
      finished_at: 1.day.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round2,
      slot: 2,
      agent_a: players[1],
      agent_b: players[3],
      pairing_status: "running",
      match_status: "running",
      started_at: 2.hours.ago
    )

    create_pairing_with_match!(
      tournament: tournament,
      round: round3,
      slot: 1,
      agent_a: players[0],
      agent_b: players[3],
      pairing_status: "pending",
      match_status: "created"
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round3,
      slot: 2,
      agent_a: players[1],
      agent_b: players[2],
      pairing_status: "pending",
      match_status: "created"
    )
  end

  def seed_live_cash_prize_tournament(agents)
    tournament = build_demo_tournament!(
      :live_cash_prize,
      {
        description: "Cash prize knockout with semifinals underway.",
        status: "running",
        format: "single_elimination",
        game_key: "chess",
        time_control: "blitz",
        rated: true,
        monied: true,
        max_players: 8,
        starts_at: 2.days.ago,
        ends_at: nil
      },
      allowed_preset_keys: %w[chess_blitz_3p2],
      locked_preset_key: "chess_blitz_3p2"
    )
    return if tournament.tournament_rounds.exists?

    players = agents.rotate(5).first(8)
    ensure_entries!(tournament, players)

    round = tournament.tournament_rounds.create!(round_number: 1, status: "running", started_at: 10.hours.ago)

    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 1,
      agent_a: players[0],
      agent_b: players[7],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 9.hours.ago,
      finished_at: 8.hours.ago
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 2,
      agent_a: players[3],
      agent_b: players[4],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 9.hours.ago,
      finished_at: 8.hours.ago
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 3,
      agent_a: players[1],
      agent_b: players[6],
      pairing_status: "running",
      match_status: "running",
      started_at: 80.minutes.ago
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: round,
      slot: 4,
      agent_a: players[2],
      agent_b: players[5],
      pairing_status: "running",
      match_status: "queued"
    )
  end

  def seed_finished_knockout_tournament(agents)
    tournament = build_demo_tournament!(
      :finished_knockout,
      {
        description: "Completed single elimination tournament.",
        status: "finished",
        format: "single_elimination",
        game_key: "chess",
        time_control: "blitz",
        rated: false,
        monied: false,
        max_players: 4,
        starts_at: 14.days.ago,
        ends_at: 12.days.ago
      },
      allowed_preset_keys: %w[chess_blitz_3p2],
      locked_preset_key: "chess_blitz_3p2"
    )
    return if tournament.tournament_rounds.exists?

    players = agents[4, 4]
    ensure_entries!(tournament, players)

    round1 = tournament.tournament_rounds.create!(round_number: 1, status: "finished", started_at: 14.days.ago, finished_at: 13.days.ago)
    round2 = tournament.tournament_rounds.create!(round_number: 2, status: "finished", started_at: 13.days.ago, finished_at: 12.days.ago)

    semifinal_1 = create_pairing_with_match!(
      tournament: tournament,
      round: round1,
      slot: 1,
      agent_a: players[0],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 14.days.ago + 2.hours,
      finished_at: 14.days.ago + 3.hours
    )
    semifinal_2 = create_pairing_with_match!(
      tournament: tournament,
      round: round1,
      slot: 2,
      agent_a: players[1],
      agent_b: players[2],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 14.days.ago + 2.hours,
      finished_at: 14.days.ago + 3.hours
    )

    create_pairing_with_match!(
      tournament: tournament,
      round: round2,
      slot: 1,
      agent_a: semifinal_1.winner_agent,
      agent_b: semifinal_2.winner_agent,
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 13.days.ago + 2.hours,
      finished_at: 13.days.ago + 3.hours
    )
  end

  def seed_finished_round_robin_tournament(agents)
    tournament = build_demo_tournament!(
      :finished_round_robin,
      {
        description: "Completed round robin tournament.",
        status: "finished",
        format: "round_robin",
        game_key: "go",
        time_control: "rapid",
        rated: false,
        monied: false,
        max_players: 4,
        starts_at: 30.days.ago,
        ends_at: 27.days.ago
      },
      allowed_preset_keys: %w[go_rapid_10m_5x30],
      locked_preset_key: "go_rapid_10m_5x30"
    )
    return if tournament.tournament_rounds.exists?

    players = agents.first(4)
    ensure_entries!(tournament, players)

    rounds = [
      tournament.tournament_rounds.create!(round_number: 1, status: "finished", started_at: 30.days.ago, finished_at: 29.days.ago),
      tournament.tournament_rounds.create!(round_number: 2, status: "finished", started_at: 29.days.ago, finished_at: 28.days.ago),
      tournament.tournament_rounds.create!(round_number: 3, status: "finished", started_at: 28.days.ago, finished_at: 27.days.ago)
    ]

    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[0],
      slot: 1,
      agent_a: players[0],
      agent_b: players[1],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 30.days.ago + 1.hour,
      finished_at: 30.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[0],
      slot: 2,
      agent_a: players[2],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "1/2-1/2",
      started_at: 30.days.ago + 1.hour,
      finished_at: 30.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[1],
      slot: 1,
      agent_a: players[0],
      agent_b: players[2],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 29.days.ago + 1.hour,
      finished_at: 29.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[1],
      slot: 2,
      agent_a: players[1],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 29.days.ago + 1.hour,
      finished_at: 29.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[2],
      slot: 1,
      agent_a: players[0],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "1/2-1/2",
      started_at: 28.days.ago + 1.hour,
      finished_at: 28.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[2],
      slot: 2,
      agent_a: players[1],
      agent_b: players[2],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 28.days.ago + 1.hour,
      finished_at: 28.days.ago + 2.hours
    )
  end

  def seed_finished_cash_prize_tournament(agents)
    tournament = build_demo_tournament!(
      :finished_cash_prize,
      {
        description: "Completed cash prize round robin season.",
        status: "finished",
        format: "round_robin",
        game_key: "chess",
        time_control: "rapid",
        rated: true,
        monied: true,
        max_players: 4,
        starts_at: 21.days.ago,
        ends_at: 18.days.ago
      },
      allowed_preset_keys: %w[chess_rapid_10p0],
      locked_preset_key: "chess_rapid_10p0"
    )
    return if tournament.tournament_rounds.exists?

    players = agents.rotate(9).first(4)
    ensure_entries!(tournament, players)

    rounds = [
      tournament.tournament_rounds.create!(round_number: 1, status: "finished", started_at: 21.days.ago, finished_at: 20.days.ago),
      tournament.tournament_rounds.create!(round_number: 2, status: "finished", started_at: 20.days.ago, finished_at: 19.days.ago),
      tournament.tournament_rounds.create!(round_number: 3, status: "finished", started_at: 19.days.ago, finished_at: 18.days.ago)
    ]

    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[0],
      slot: 1,
      agent_a: players[0],
      agent_b: players[1],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 21.days.ago + 1.hour,
      finished_at: 21.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[0],
      slot: 2,
      agent_a: players[2],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 21.days.ago + 1.hour,
      finished_at: 21.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[1],
      slot: 1,
      agent_a: players[0],
      agent_b: players[2],
      pairing_status: "finished",
      match_status: "finished",
      result: "1/2-1/2",
      started_at: 20.days.ago + 1.hour,
      finished_at: 20.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[1],
      slot: 2,
      agent_a: players[1],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 20.days.ago + 1.hour,
      finished_at: 20.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[2],
      slot: 1,
      agent_a: players[0],
      agent_b: players[3],
      pairing_status: "finished",
      match_status: "finished",
      result: "0-1",
      started_at: 19.days.ago + 1.hour,
      finished_at: 19.days.ago + 2.hours
    )
    create_pairing_with_match!(
      tournament: tournament,
      round: rounds[2],
      slot: 2,
      agent_a: players[1],
      agent_b: players[2],
      pairing_status: "finished",
      match_status: "finished",
      result: "1-0",
      started_at: 19.days.ago + 1.hour,
      finished_at: 19.days.ago + 2.hours
    )
  end

  def seed_cancelled_tournament(agents)
    tournament = build_demo_tournament!(
      :cancelled,
      {
        description: "Cancelled before round generation after registration closed.",
        status: "cancelled",
        format: "single_elimination",
        game_key: "go",
        time_control: "rapid",
        rated: false,
        monied: false,
        max_players: 8,
        starts_at: 9.days.ago,
        ends_at: 8.days.ago
      },
      allowed_preset_keys: %w[go_rapid_10m_5x30],
      locked_preset_key: "go_rapid_10m_5x30"
    )
    return if tournament.tournament_entries.exists?

    ensure_entries!(tournament, agents.rotate(2).first(4))
  end

  def seed_invalid_tournament(agents)
    tournament = build_demo_tournament!(
      :invalid,
      {
        description: "Cash prize event invalidated after adjudication review.",
        status: "invalid",
        format: "single_elimination",
        game_key: "chess",
        time_control: "blitz",
        rated: true,
        monied: true,
        max_players: 4,
        starts_at: 25.days.ago,
        ends_at: 24.days.ago
      },
      allowed_preset_keys: %w[chess_blitz_3p2],
      locked_preset_key: "chess_blitz_3p2"
    )

    players = agents.rotate(11).first(4)
    ensure_entries!(tournament, players) unless tournament.tournament_entries.exists?
    return if tournament.tournament_rounds.exists?

    round = tournament.tournament_rounds.create!(
      round_number: 1,
      status: "finished",
      started_at: 25.days.ago + 1.hour,
      finished_at: 25.days.ago + 2.hours
    )
    pairing = TournamentPairing.create!(
      tournament: tournament,
      tournament_round: round,
      slot: 1,
      agent_a: players[0],
      agent_b: players[1],
      status: "finished",
      bye: false
    )

    Match.create!(
      tournament: tournament,
      tournament_pairing: pairing,
      game_key: tournament.game_key,
      rated: tournament.rated,
      time_control: tournament.time_control,
      time_control_preset: time_control_preset_for_tournament(tournament),
      agent_a: pairing.agent_a,
      agent_b: pairing.agent_b,
      status: "invalid",
      result: "1-0",
      winner_side: "a",
      termination: "checkmate",
      pgn: "[Event \"#{tournament.name}\"]",
      started_at: 25.days.ago + 1.hour,
      finished_at: 25.days.ago + 2.hours
    )
  end

  def ensure_entries!(tournament, agents)
    agents.each_with_index do |agent, idx|
      entry = TournamentEntry.find_or_initialize_by(tournament: tournament, agent: agent)
      entry.status = "registered"
      entry.seed = idx + 1
      entry.save!
    end
  end

  def time_control_preset_for_tournament(tournament)
    scope = TimeControlPreset.active.where(game_key: tournament.game_key)
    scope = scope.where(rated_allowed: true) if tournament.rated?

    if tournament.locked_time_control_preset_id.present?
      scope = scope.where(id: tournament.locked_time_control_preset_id)
    elsif tournament.tournament_time_control_presets.exists?
      scope = scope.where(id: tournament.allowed_time_control_presets.select(:id))
    end

    preferred = tournament.time_control.present? ? scope.where(category: tournament.time_control).order(:key).first : nil
    preferred || scope.order(:key).first
  end

  def create_pairing_with_match!(tournament:, round:, slot:, agent_a:, agent_b:, pairing_status:, match_status:, result: nil, started_at: nil, finished_at: nil)
    pairing = TournamentPairing.create!(
      tournament: tournament,
      tournament_round: round,
      slot: slot,
      agent_a: agent_a,
      agent_b: agent_b,
      status: pairing_status,
      bye: false,
      winner_agent: winner_for_result(tournament.game_key, result, agent_a, agent_b)
    )

    create_tournament_match!(
      tournament: tournament,
      pairing: pairing,
      match_status: match_status,
      result: result,
      started_at: started_at,
      finished_at: finished_at
    )

    pairing
  end

  def create_tournament_match!(tournament:, pairing:, match_status:, result:, started_at:, finished_at:)
    initial_status = if %w[created queued].include?(match_status)
      match_status
    else
      "running"
    end
    preset = time_control_preset_for_tournament(tournament)
    if tournament.rated? && preset.blank?
      raise ArgumentError, "No eligible time control preset found for rated tournament #{tournament.name}"
    end

    match = Match.create!(
      tournament: tournament,
      tournament_pairing: pairing,
      game_key: tournament.game_key,
      rated: tournament.rated,
      time_control: tournament.time_control,
      time_control_preset: preset,
      agent_a: pairing.agent_a,
      agent_b: pairing.agent_b,
      status: initial_status
    )

    if initial_status == "running"
      seed_tournament_match_moves!(match, finished: match_status == "finished")
      match.update_columns(started_at: started_at || match.started_at || match.created_at, updated_at: Time.current)
    end

    if match_status == "finished" && result.present?
      finalize_tournament_match!(
        match,
        result: result,
        started_at: started_at,
        finished_at: finished_at
      )
      return match
    end

    if match_status == "running"
      match.update_columns(status: "running", updated_at: Time.current)
    elsif match_status == "queued"
      match.update_columns(status: "queued", started_at: nil, updated_at: Time.current)
    end

    match
  end

  def seed_tournament_match_moves!(match, finished:)
    if match.game_key == "go"
      size = match.game_config.fetch("board_size", 19)
      if finished
        apply_go_opening(match, go_opening_for_size(size))
      else
        opening = go_opening_for_size(size).reject { |move| move == "pass" }
        opening = %w[D4 Q16 D16 Q4 C4 R16] if opening.empty?
        apply_go_moves(match, opening.first([ opening.length, 6 ].min))
      end
    else
      opening = OPENINGS.sample
      moves = finished ? opening : opening.first([ opening.length, 6 ].min)
      apply_chess_moves(match, moves)
    end
  end

  def finalize_tournament_match!(match, result:, started_at:, finished_at:)
    rules = GameRegistry.fetch!(match.game_key)
    finished_time = finished_at || Time.current

    match.update_columns(
      status: "finished",
      result: result,
      winner_side: winner_side_for_result(match.game_key, result),
      termination: rules.termination_for_result(result),
      started_at: started_at || match.started_at || match.created_at,
      finished_at: finished_time,
      updated_at: finished_time
    )

    tags = {
      event: match.tournament&.name || "Tournaiment Demo",
      site: "Tournaiment Demo",
      date: finished_time.to_date,
      round: match.tournament_pairing&.tournament_round&.round_number.to_s,
      white: match.agent_a.name,
      black: match.agent_b.name
    }
    moves = match.moves.order(:ply).pluck(:display)
    record = rules.render_record(moves: moves, result: result, tags: tags)
    match.update_columns(pgn: record, updated_at: finished_time)

    RatingService.new(match).apply!
    RatingChange.where(match_id: match.id).update_all(created_at: finished_time)
  end

  def winner_side_for_result(game_key, result)
    return nil if result.blank?

    rules = GameRegistry.fetch!(game_key)
    scores = rules.scores_for_result(result)
    first_actor = rules.actors.first
    second_actor = rules.actors.second
    return "a" if scores.fetch(first_actor, 0.0) > scores.fetch(second_actor, 0.0)
    return "b" if scores.fetch(second_actor, 0.0) > scores.fetch(first_actor, 0.0)

    nil
  end

  def winner_for_result(game_key, result, agent_a, agent_b)
    side = winner_side_for_result(game_key, result)
    return agent_a if side == "a"
    return agent_b if side == "b"

    nil
  end

  def random_past_time
    days = (ENV["SEED_BACKDATE_DAYS"] || "120").to_i
    Time.current - rand(1..days).days - rand(0..23).hours - rand(0..59).minutes
  end

  def backdate_agents
    days = (ENV["SEED_BACKDATE_DAYS"] || "120").to_i
    Agent.where(name: agent_names).find_each do |agent|
      next if agent.created_at < Time.current - 1.day

      ts = Time.current - rand(10..days).days
      agent.update_columns(created_at: ts, updated_at: ts)
    end
  end

  def reset_match_state!(match)
    match.moves.delete_all
    match.update_columns(
      current_state: match.initial_state,
      current_fen: match.initial_state,
      ply_count: 0,
      updated_at: Time.current
    )
  end

  def agent_names
    target = (ENV["SEED_AGENTS"] || "24").to_i
    names = BASE_AGENT_NAMES.dup
    return names.first(target) if target <= names.length

    used = names.to_h { |name| [ name, true ] }
    while names.length < target
      prefix = AGENT_PREFIXES.sample
      suffix = AGENT_SUFFIXES.sample
      candidate = "#{prefix}#{suffix}"
      next if used[candidate]

      used[candidate] = true
      names << candidate
    end
    names
  end

  def load_chess_pgn_games
    files = Dir.glob(File.join(__dir__, "..", "db", "seed_games", "chess", "*.pgn")).sort
    games = []
    limit = (ENV["SEED_REAL_CHESS_LIMIT"] || ENV["SEED_REAL_LIMIT"] || "1000").to_i
    files.each do |path|
      content = File.read(path)
      parse_pgn_games(content).each do |game|
        next if game[:moves].empty?

        games << { moves: game[:moves], result: game[:headers]["Result"] }
        return games if games.length >= limit
      end
    end
    games
  end

  def parse_pgn_games(content)
    games = []
    headers = {}
    move_lines = []

    content.each_line do |line|
      stripped = line.strip
      if stripped.start_with?("[")
        if headers.any? || move_lines.any?
          games << { headers: headers, moves: parse_pgn_moves(move_lines) }
          headers = {}
          move_lines = []
        end
        if stripped.match(/\A\[(\w+)\s+\"(.*)\"\]\z/)
          headers[Regexp.last_match(1)] = Regexp.last_match(2)
        end
      elsif stripped.empty?
        if move_lines.any?
          games << { headers: headers, moves: parse_pgn_moves(move_lines) }
          headers = {}
          move_lines = []
        end
      else
        move_lines << stripped
      end
    end

    if headers.any? || move_lines.any?
      games << { headers: headers, moves: parse_pgn_moves(move_lines) }
    end

    games
  end

  def parse_pgn_moves(move_lines)
    moves_text = move_lines.join(" ")
    moves_text = moves_text.gsub(/\{[^}]*\}/, " ")
    moves_text = moves_text.gsub(/;[^\n]*/, " ")
    loop do
      stripped = moves_text.gsub(/\([^()]*\)/, " ")
      break if stripped == moves_text

      moves_text = stripped
    end
    moves_text = moves_text.gsub(/\d+\.(\.\.)?/, " ")
    moves_text = moves_text.gsub(/\$\d+/, " ")
    tokens = moves_text.split(/\s+/).reject(&:empty?)
    tokens.reject! { |token| %w[1-0 0-1 1/2-1/2 *].include?(token) }

    tokens
  end

  def load_go_sgf_games
    files = Dir.glob(File.join(__dir__, "..", "db", "seed_games", "go", "**", "*.sgf")).sort
    games = []
    limit = (ENV["SEED_REAL_GO_LIMIT"] || ENV["SEED_REAL_LIMIT"] || "1000").to_i
    files.each do |path|
      content = File.read(path)
      size = content[/SZ\[(\d+)\]/, 1].to_i
      size = 19 if size.zero?
      next unless [ 9, 13, 19 ].include?(size)

      result_tag = content[/RE\[([^\]]+)\]/, 1]
      result = sgf_result_to_match(result_tag)
      moves = content.scan(/;[BW]\[([a-z]{0,2})\]/).flatten.map do |coord|
        sgf_to_gtp(coord, size)
      end.compact
      next if moves.empty?

      games << { moves: moves, size: size, result: result }
      return games if games.length >= limit
    end
    games
  end

  def sgf_to_gtp(coord, size)
    return "pass" if coord.blank?
    return nil unless coord.length == 2

    col_idx = coord[0].ord - "a".ord
    row_idx = coord[1].ord - "a".ord
    return nil if col_idx.negative? || row_idx.negative?
    return nil if col_idx >= size || row_idx >= size

    col_letter = GoRules.gtp_columns[col_idx]
    row = size - row_idx
    "#{col_letter}#{row}"
  end

  def sgf_result_to_match(result_tag)
    return nil if result_tag.blank?
    return "1-0" if result_tag.start_with?("W+")
    return "0-1" if result_tag.start_with?("B+")
    return "1/2-1/2" if result_tag.include?("0") || result_tag.include?("Draw")

    nil
  end
end

DemoSeed.run!
