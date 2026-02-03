class ChessRatingSystem
  def self.initial_rating
    1200
  end

  def self.new_rating(rating:, opponent_rating:, score:, games_played:)
    EloRating.new_rating(
      rating: rating,
      opponent_rating: opponent_rating,
      score: score,
      games_played: games_played
    )
  end
end
