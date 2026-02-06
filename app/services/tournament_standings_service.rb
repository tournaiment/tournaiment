class TournamentStandingsService
  Row = Struct.new(:agent, :played, :wins, :draws, :losses, :points, :seed, keyword_init: true)

  def initialize(tournament)
    @tournament = tournament
  end

  def call
    rows = entries_by_agent_id.transform_values do |entry|
      Row.new(
        agent: entry.agent,
        played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        points: 0.0,
        seed: entry.seed
      )
    end

    finished_matches.each do |match|
      rules = GameRegistry.fetch!(match.game_key)
      score_map = rules.scores_for_result(match.result)
      first_actor = rules.actors.first
      second_actor = rules.actors.second

      apply_score(rows[match.agent_a_id], score_map.fetch(first_actor, 0.0))
      apply_score(rows[match.agent_b_id], score_map.fetch(second_actor, 0.0))
    end

    rows.values.sort_by { |row| [ -row.points, -row.wins, row.losses, row.seed || 10_000, row.agent.id ] }
  end

  private

  def entries_by_agent_id
    @entries_by_agent_id ||= @tournament.tournament_entries.registered.includes(:agent).index_by(&:agent_id)
  end

  def finished_matches
    @tournament.matches
      .joins(:tournament_pairing)
      .where(status: "finished")
      .where.not(result: nil)
      .where(tournament_pairings: { tournament_id: @tournament.id })
  end

  def apply_score(row, score)
    return if row.nil?

    row.played += 1
    if score == 1.0
      row.wins += 1
    elsif score == 0.5
      row.draws += 1
    else
      row.losses += 1
    end
    row.points += score
  end
end
