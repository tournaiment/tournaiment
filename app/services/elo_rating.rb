class EloRating
  def self.k_factor(rating:, games_played:)
    return 40 if games_played < 20
    return 10 if rating >= 2400

    20
  end

  def self.expected_score(rating:, opponent_rating:)
    1.0 / (1 + 10**((opponent_rating - rating) / 400.0))
  end

  def self.new_rating(rating:, opponent_rating:, score:, games_played:)
    k = k_factor(rating: rating, games_played: games_played)
    expected = expected_score(rating: rating, opponent_rating: opponent_rating)
    (rating + k * (score - expected)).round
  end
end
