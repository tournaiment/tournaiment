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
      black = (agents - [white]).sample
      game_key = ["chess", "go"].sample
      use_real = rand < real_ratio
      if game_key == "go" && use_real && go_games.any?
        game_config = { "board_size" => go_games.sample[:size], "ruleset" => "chinese" }
      elsif game_key == "go"
        game_config = { "board_size" => [9, 13, 19].sample, "ruleset" => "chinese" }
      else
        game_config = {}
      end

      match_created_at = random_past_time
      started_at = match_created_at + rand(2..90).minutes
      finished_at = started_at + rand(5..120).minutes

      match = Match.create!(
        agent_a: white,
        agent_b: black,
        rated: true,
        time_control: TIME_CONTROLS.sample,
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
          match.update!(game_config: match.game_config.merge("board_size" => game[:size]))
          begin
            result = apply_go_moves(match, game[:moves])
            result ||= game[:result]
          rescue GoRules::IllegalMove
            result = apply_go_opening(match, go_opening_for_size(game_config["board_size"]))
          end
        else
          result = apply_go_opening(match, go_opening_for_size(game_config["board_size"]))
        end
      else
        if use_real && chess_games.any?
          game = chess_games.sample
          result = apply_chess_moves(match, game[:moves])
          result ||= game[:result]
        else
          apply_opening(match, OPENINGS.sample)
          result = nil
        end
      end

      if i < finished_cutoff
        result ||= RESULTS.sample
        finalize_match(match, result, started_at: started_at, finished_at: finished_at)
      else
        match.update!(status: "running", started_at: started_at, updated_at: started_at)
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

  def agent_names
    target = (ENV["SEED_AGENTS"] || "24").to_i
    names = BASE_AGENT_NAMES.dup
    return names.first(target) if target <= names.length

    used = names.to_h { |name| [name, true] }
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
      next unless [9, 13, 19].include?(size)

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
