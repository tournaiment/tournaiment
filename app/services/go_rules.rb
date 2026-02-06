require "json"

class GoRules
  class IllegalMove < StandardError; end
  def self.key
    "go"
  end

  def self.actors
    %w[black white]
  end

  def self.starting_state(config: {})
    ruleset = normalize_ruleset(config["ruleset"])
    size = normalize_board_size(config["board_size"])
    komi = normalize_komi(config["komi"], ruleset)

    state = {
      "ruleset" => ruleset,
      "size" => size,
      "komi" => komi,
      "board" => "." * (size * size),
      "to_move" => "black",
      "ko" => nil,
      "passes" => 0,
      "captures" => { "black" => 0, "white" => 0 }
    }

    JSON.generate(state)
  end

  def self.actor_for_ply(ply_count)
    actors[ply_count % actors.length]
  end

  def self.turn_number_for_ply(ply)
    ply
  end

  def self.apply_move(state:, move:, actor:)
    data = parse_state(state)
    validate_actor!(data, actor)

    if move == "pass"
      return apply_pass(data)
    end

    return illegal!("invalid_move") unless valid_move_notation?(move, data["size"])

    index = coord_to_index(move, data["size"])
    return illegal!("occupied") unless cell_at(data["board"], index) == "."
    return illegal!("ko_violation") if data["ko"] && coord_to_index(data["ko"], data["size"]) == index

    board = data["board"].dup
    board[index] = actor == "black" ? "b" : "w"

    captured = capture_adjacent_groups(board, data["size"], index, actor)
    data["captures"] ||= { "black" => 0, "white" => 0 }
    data["captures"][actor] = data["captures"].fetch(actor, 0) + captured.length

    if group_liberties(board, data["size"], index).zero?
      return illegal!("suicide")
    end

    ko = compute_ko(data, captured, index, board)

    data["board"] = board
    data["to_move"] = opponent(actor)
    data["ko"] = ko
    data["passes"] = 0

    {
      notation: move,
      display: move,
      state: JSON.generate(data),
      result: nil,
      status: "running"
    }
  end

  def self.render_record(moves:, result:, tags: {})
    # Minimal record format: one move per line, followed by result.
    lines = []
    tags.each do |key, value|
      lines << "#{key}: #{value}"
    end
    lines << "Result: #{result}" if result.present?
    lines << "Moves:"
    lines.concat(moves)
    lines.join("\n")
  end

  def self.scores_for_result(result)
    case result
    when "1-0"
      { "white" => 1.0, "black" => 0.0 }
    when "0-1"
      { "white" => 0.0, "black" => 1.0 }
    when "1/2-1/2"
      { "white" => 0.5, "black" => 0.5 }
    else
      { "white" => 0.0, "black" => 0.0 }
    end
  end

  def self.termination_for_result(_result)
    "score"
  end

  def self.parse_state(state)
    data = JSON.parse(state)
    validate_state!(data)
    data
  rescue JSON::ParserError
    raise ArgumentError, "Invalid Go state JSON"
  end

  def self.validate_actor!(data, actor)
    raise ArgumentError, "Invalid actor" unless actors.include?(actor)
    raise ArgumentError, "Not actor's turn" unless data["to_move"] == actor
  end

  def self.apply_pass(data)
    data["passes"] = data.fetch("passes", 0) + 1
    data["to_move"] = opponent(data["to_move"])
    data["ko"] = nil
    data["captures"] ||= { "black" => 0, "white" => 0 }

    if data["passes"] >= 2
      result = score_game(data)
      return {
        notation: "pass",
        display: "pass",
        state: JSON.generate(data),
        result: result,
        status: "finished"
      }
    end

    {
      notation: "pass",
      display: "pass",
      state: JSON.generate(data),
      result: nil,
      status: "running"
    }
  end

  def self.score_game(data)
    size = data["size"]
    board = data["board"]
    territory = count_territory(board, size)
    stones = count_stones(board)
    captures = data["captures"] || { "black" => 0, "white" => 0 }

    case data["ruleset"]
    when "chinese"
      black_score = stones["black"] + territory["black"]
      white_score = stones["white"] + territory["white"] + data["komi"].to_f
    when "japanese", "korean"
      black_score = territory["black"] + captures.fetch("black", 0)
      white_score = territory["white"] + captures.fetch("white", 0) + data["komi"].to_f
    else
      raise NotImplementedError, "Unsupported Go ruleset: #{data["ruleset"]}"
    end

    if white_score > black_score
      "1-0"
    elsif black_score > white_score
      "0-1"
    else
      "1/2-1/2"
    end
  end

  def self.count_stones(board)
    counts = { "black" => 0, "white" => 0 }
    board.each_char do |cell|
      counts["black"] += 1 if cell == "b"
      counts["white"] += 1 if cell == "w"
    end
    counts
  end

  def self.count_territory(board, size)
    visited = Array.new(board.length, false)
    territory = { "black" => 0, "white" => 0 }

    board.length.times do |idx|
      next if visited[idx]
      next unless cell_at(board, idx) == "."

      region, bordering = flood_region(board, size, idx, visited)
      next if bordering.empty?

      owner = bordering.uniq
      next unless owner.length == 1

      color = owner.first == "b" ? "black" : "white"
      territory[color] += region.length
    end

    territory
  end

  def self.flood_region(board, size, start_idx, visited)
    region = []
    bordering = []
    queue = [ start_idx ]
    visited[start_idx] = true

    until queue.empty?
      idx = queue.pop
      region << idx
      neighbors(idx, size).each do |n|
        cell = cell_at(board, n)
        if cell == "." && !visited[n]
          visited[n] = true
          queue << n
        elsif cell != "."
          bordering << cell
        end
      end
    end

    [ region, bordering ]
  end

  def self.capture_adjacent_groups(board, size, placed_idx, actor)
    captured = []
    opponent_color = actor == "black" ? "w" : "b"

    neighbors(placed_idx, size).each do |n|
      next unless cell_at(board, n) == opponent_color

      group = collect_group(board, size, n)
      if group_liberties(board, size, group.first).zero?
        group.each { |idx| board[idx] = "." }
        captured.concat(group)
      end
    end

    captured
  end

  def self.group_liberties(board, size, start_idx)
    group = collect_group(board, size, start_idx)
    liberties = {}
    group.each do |idx|
      neighbors(idx, size).each do |n|
        liberties[n] = true if cell_at(board, n) == "."
      end
    end
    liberties.length
  end

  def self.collect_group(board, size, start_idx)
    color = cell_at(board, start_idx)
    return [] if color == "."

    group = []
    stack = [ start_idx ]
    visited = {}

    until stack.empty?
      idx = stack.pop
      next if visited[idx]

      visited[idx] = true
      group << idx
      neighbors(idx, size).each do |n|
        stack << n if cell_at(board, n) == color
      end
    end

    group
  end

  def self.compute_ko(data, captured, placed_idx, board)
    return nil unless captured.length == 1

    liberties = group_liberties(board, data["size"], placed_idx)
    return nil unless liberties == 1

    index_to_coord(captured.first, data["size"])
  end

  def self.neighbors(idx, size)
    row = idx / size
    col = idx % size
    n = []
    n << (idx - size) if row.positive?
    n << (idx + size) if row < size - 1
    n << (idx - 1) if col.positive?
    n << (idx + 1) if col < size - 1
    n
  end

  def self.opponent(actor)
    actor == "black" ? "white" : "black"
  end

  def self.valid_move_notation?(move, size)
    return false unless move.match?(/\A[A-Za-z][0-9]+\z/)
    col_char = move[0].upcase
    row = move[1..].to_i
    return false if row < 1 || row > size

    col = gtp_columns.index(col_char)
    return false if col.nil? || col >= size

    true
  end

  def self.coord_to_index(move, size)
    col_char = move[0].upcase
    row = move[1..].to_i
    col = gtp_columns.index(col_char)
    row_from_top = size - row
    row_from_top * size + col
  end

  def self.index_to_coord(idx, size)
    row_from_top = idx / size
    col = idx % size
    row = size - row_from_top
    "#{gtp_columns[col]}#{row}"
  end

  def self.gtp_columns
    @gtp_columns ||= ("A".."T").to_a.reject { |letter| letter == "I" }
  end

  def self.normalize_ruleset(ruleset)
    value = ruleset.to_s.downcase
    return "chinese" if value.blank? || value == "chinese"
    return "japanese" if value == "japanese"
    return "korean" if value == "korean"

    raise ArgumentError, "Unsupported Go ruleset: #{ruleset}"
  end

  def self.normalize_board_size(size)
    value = size.to_i
    return 19 if value.zero?
    return value if [ 9, 13, 19 ].include?(value)

    raise ArgumentError, "Unsupported Go board size: #{size}"
  end

  def self.normalize_komi(komi, ruleset)
    return 7.5 if komi.nil? || komi.to_s.strip.empty?
    komi.to_f
  end

  def self.illegal!(reason)
    raise IllegalMove, "Illegal move: #{reason}"
  end

  def self.cell_at(board, idx)
    board.getbyte(idx)&.chr
  end

  def self.validate_state!(data)
    size = data["size"].to_i
    return illegal!("invalid_size") unless [ 9, 13, 19 ].include?(size)

    board = data["board"].to_s
    return illegal!("invalid_board") unless board.length == size * size
    return illegal!("invalid_board") unless board.match?(/\A[\.bw]+\z/)

    captures = data["captures"]
    return illegal!("invalid_captures") unless captures.is_a?(Hash)
    illegal!("invalid_captures") unless captures.key?("black") && captures.key?("white")
  end
end
