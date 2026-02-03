require "chess"

class ChessRules
  class IllegalMove < StandardError; end
  class BadNotation < StandardError; end
  class InvalidFen < StandardError; end

  STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  def self.key
    "chess"
  end

  def self.actors
    %w[white black]
  end

  def self.starting_state(config: {})
    STARTING_FEN
  end

  def self.actor_for_ply(ply_count)
    actors[ply_count % actors.length]
  end

  def self.turn_number_for_ply(ply)
    (ply + 1) / 2
  end

  def self.apply_move(state:, move:, actor:)
    game = Chess::Game.load_fen(state)
    san = game.move(move)
    {
      notation: move,
      display: san,
      state: game.board.to_fen,
      result: game.result,
      status: game.status
    }
  rescue Chess::IllegalMoveError => e
    raise IllegalMove, e.message
  rescue Chess::BadNotationError => e
    raise BadNotation, e.message
  rescue Chess::InvalidFenFormatError => e
    raise InvalidFen, e.message
  end

  def self.render_record(moves:, result:, tags: {})
    pgn = Chess::Pgn.new
    pgn.moves = moves
    pgn.result = result.presence || "*"

    tags.each do |key, value|
      next unless pgn.respond_to?("#{key}=")

      pgn.public_send("#{key}=", value)
    end

    pgn.to_s
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

  def self.termination_for_result(result)
    case result
    when "1-0", "0-1"
      "checkmate"
    when "1/2-1/2"
      "draw"
    else
      "draw"
    end
  end
end
