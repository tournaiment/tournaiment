class RatingService
  MAX_PAIR_RATED_PER_DAY = 10

  def initialize(match)
    @match = match
  end

  def apply!
    return unless @match.rated?
    return unless @match.status == "finished"
    return if @match.result.blank?
    return if RatingChange.exists?(match_id: @match.id)

    if anti_farming_blocked?
      AuditLog.log!(actor: nil, action: "rating.skipped", auditable: @match, metadata: { reason: "pair_limit" })
      return
    end

    white_rating = rating_for(@match.agent_a)
    black_rating = rating_for(@match.agent_b)

    score_map = scores
    white_score = score_map.fetch("white", 0.0)
    black_score = score_map.fetch("black", 0.0)

    rating_system = RatingSystemRegistry.fetch!(@match.game_key)
    new_white = rating_system.new_rating(
      rating: white_rating.current,
      opponent_rating: black_rating.current,
      score: white_score,
      games_played: white_rating.games_played
    )
    new_black = rating_system.new_rating(
      rating: black_rating.current,
      opponent_rating: white_rating.current,
      score: black_score,
      games_played: black_rating.games_played
    )

    white_before = white_rating.current
    black_before = black_rating.current

    Rating.transaction do

      apply_change!(white_rating, new_white)
      apply_change!(black_rating, new_black)

      RatingChange.create!(
        match: @match,
        agent: @match.agent_a,
        before_rating: white_before,
        after_rating: new_white,
        delta: new_white - white_before,
        created_at: Time.current
      )
      RatingChange.create!(
        match: @match,
        agent: @match.agent_b,
        before_rating: black_before,
        after_rating: new_black,
        delta: new_black - black_before,
        created_at: Time.current
      )
    end

    AuditLog.log!(
      actor: nil,
      action: "rating.applied",
      auditable: @match,
      metadata: { white_delta: new_white - white_before, black_delta: new_black - black_before }
    )
  end

  def rollback!
    changes = RatingChange.where(match_id: @match.id).includes(:agent)
    return if changes.empty?

    Rating.transaction do
      changes.each do |change|
        rating = rating_for(change.agent)
        rating.update!(current: change.before_rating, games_played: [rating.games_played - 1, 0].max)
      end
      changes.delete_all
    end

    AuditLog.log!(actor: nil, action: "rating.rolled_back", auditable: @match)
  end

  private

  def rating_for(agent)
    agent.ratings.find_or_create_by!(game_key: @match.game_key) do |rating|
      rating.current = RatingSystemRegistry.fetch!(@match.game_key).initial_rating
    end
  end

  def scores
    GameRegistry.fetch!(@match.game_key).scores_for_result(@match.result)
  end

  def apply_change!(rating, new_value)
    rating.update!(current: new_value, games_played: rating.games_played + 1)
  end

  def anti_farming_blocked?
    cutoff = 24.hours.ago
    match_count = Match.where(rated: true)
      .where(status: "finished")
      .where(game_key: @match.game_key)
      .where("finished_at >= ?", cutoff)
      .where("(agent_a_id = ? AND agent_b_id = ?) OR (agent_a_id = ? AND agent_b_id = ?)",
             @match.agent_a_id, @match.agent_b_id, @match.agent_b_id, @match.agent_a_id)
      .count

    match_count >= MAX_PAIR_RATED_PER_DAY
  end
end
