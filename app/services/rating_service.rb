class RatingService
  MAX_PAIR_RATED_PER_DAY = 10

  def initialize(match)
    @match = match
  end

  def apply!
    return unless rateable_match?(@match)
    return if RatingChange.exists?(match_id: @match.id)

    if anti_farming_blocked?(@match)
      AuditLog.log!(actor: nil, action: "rating.skipped", auditable: @match, metadata: { reason: "pair_limit" })
      return
    end

    deltas = {}
    Rating.transaction { deltas = apply_rating_change_for_match!(@match) }

    AuditLog.log!(
      actor: nil,
      action: "rating.applied",
      auditable: @match,
      metadata: { white_delta: deltas.fetch("white", 0), black_delta: deltas.fetch("black", 0) }
    )
  end

  def rollback!
    return unless RatingChange.exists?(match_id: @match.id)

    Rating.transaction do
      rebuild_game_ratings!(game_key: @match.game_key, excluded_match_id: @match.id)
    end

    AuditLog.log!(actor: nil, action: "rating.rolled_back", auditable: @match)
  end

  private

  def rateable_match?(match)
    match.rated? && match.status == "finished" && match.result.present?
  end

  def rebuild_game_ratings!(game_key:, excluded_match_id:)
    reset_game_ratings!(game_key)
    RatingChange.joins(:match).where(matches: { game_key: game_key }).delete_all

    pair_history = Hash.new { |memo, key| memo[key] = [] }

    replayable_matches(game_key: game_key, excluded_match_id: excluded_match_id).each do |match|
      timestamp = match_timestamp(match)
      next if pair_limit_reached_for_rebuild?(pair_history, match, timestamp)

      apply_rating_change_for_match!(match)
      track_pair_history!(pair_history, match, timestamp)
    end
  end

  def reset_game_ratings!(game_key)
    initial = RatingSystemRegistry.fetch!(game_key).initial_rating
    Rating.where(game_key: game_key).update_all(current: initial, games_played: 0, updated_at: Time.current)
  end

  def replayable_matches(game_key:, excluded_match_id:)
    Match.where(rated: true, status: "finished", game_key: game_key)
      .where.not(result: nil)
      .where.not(id: excluded_match_id)
      .order(Arel.sql("COALESCE(finished_at, created_at) ASC"), :id)
  end

  def pair_limit_reached_for_rebuild?(pair_history, match, timestamp)
    history = pair_history[pair_key_for(match)]
    cutoff = timestamp - 24.hours
    history.reject! { |value| value < cutoff }
    history.size >= MAX_PAIR_RATED_PER_DAY
  end

  def track_pair_history!(pair_history, match, timestamp)
    pair_history[pair_key_for(match)] << timestamp
  end

  def pair_key_for(match)
    [ match.agent_a_id, match.agent_b_id ].sort.join(":")
  end

  def apply_rating_change_for_match!(match)
    rules = GameRegistry.fetch!(match.game_key)
    first_actor = rules.actors.first
    second_actor = rules.actors.second

    first_agent = agent_for_actor!(match, first_actor)
    second_agent = agent_for_actor!(match, second_actor)
    first_rating = rating_for(first_agent, match.game_key)
    second_rating = rating_for(second_agent, match.game_key)

    score_map = rules.scores_for_result(match.result)
    first_score = score_map.fetch(first_actor, 0.0)
    second_score = score_map.fetch(second_actor, 0.0)

    rating_system = RatingSystemRegistry.fetch!(match.game_key)
    new_first = rating_system.new_rating(
      rating: first_rating.current,
      opponent_rating: second_rating.current,
      score: first_score,
      games_played: first_rating.games_played
    )
    new_second = rating_system.new_rating(
      rating: second_rating.current,
      opponent_rating: first_rating.current,
      score: second_score,
      games_played: second_rating.games_played
    )

    first_before = first_rating.current
    second_before = second_rating.current

    apply_change!(first_rating, new_first)
    apply_change!(second_rating, new_second)

    timestamp = match_timestamp(match)
    RatingChange.create!(
      match: match,
      agent: first_agent,
      before_rating: first_before,
      after_rating: new_first,
      delta: new_first - first_before,
      created_at: timestamp
    )
    RatingChange.create!(
      match: match,
      agent: second_agent,
      before_rating: second_before,
      after_rating: new_second,
      delta: new_second - second_before,
      created_at: timestamp
    )

    {
      first_actor => new_first - first_before,
      second_actor => new_second - second_before
    }
  end

  def rating_for(agent, game_key)
    agent.ratings.find_or_create_by!(game_key: game_key) do |rating|
      rating.current = RatingSystemRegistry.fetch!(game_key).initial_rating
    end
  end

  def apply_change!(rating, new_value)
    rating.update!(current: new_value, games_played: rating.games_played + 1)
  end

  def anti_farming_blocked?(match)
    timestamp = match_timestamp(match)
    cutoff = timestamp - 24.hours
    match_count = Match.where(rated: true)
      .where(status: "finished")
      .where(game_key: match.game_key)
      .where.not(result: nil)
      .where.not(id: match.id)
      .where("(agent_a_id = ? AND agent_b_id = ?) OR (agent_a_id = ? AND agent_b_id = ?)",
             match.agent_a_id, match.agent_b_id, match.agent_b_id, match.agent_a_id)
      .where("COALESCE(finished_at, created_at) >= ?", cutoff)
      .where(
        "COALESCE(finished_at, created_at) < ? OR (COALESCE(finished_at, created_at) = ? AND id < ?)",
        timestamp,
        timestamp,
        match.id
      )
      .count

    match_count >= MAX_PAIR_RATED_PER_DAY
  end

  def match_timestamp(match)
    match.finished_at || match.created_at || Time.current
  end

  def agent_for_actor!(match, actor)
    agent = match.agent_for_actor(actor)
    return agent if agent.present?

    raise ArgumentError, "Match #{match.id} missing agent for actor #{actor}"
  end
end
