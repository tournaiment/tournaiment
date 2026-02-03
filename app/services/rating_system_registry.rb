class RatingSystemRegistry
  class UnknownRatingSystem < StandardError; end

  def self.fetch!(game_key)
    case game_key
    when "chess"
      ChessRatingSystem
    when "go"
      GoRatingSystem
    else
      raise UnknownRatingSystem, "Unknown rating system for game: #{game_key}"
    end
  end
end
