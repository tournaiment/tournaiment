require "chess"

class ChessRules
  class IllegalMove < StandardError; end
  class BadNotation < StandardError; end
  class InvalidFen < StandardError; end

  STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  def self.apply_uci!(fen:, uci:)
    game = Chess::Game.load_fen(fen)
    san = game.move(uci)
    {
      san: san,
      fen: game.board.to_fen,
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

  def self.build_pgn(moves:, result:, tags: {})
    pgn = Chess::Pgn.new
    pgn.moves = moves
    pgn.result = result.presence || "*"

    tags.each do |key, value|
      next unless pgn.respond_to?("#{key}=")

      pgn.public_send("#{key}=", value)
    end

    pgn.to_s
  end
end
