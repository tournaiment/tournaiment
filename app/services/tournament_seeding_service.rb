class TournamentSeedingService
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    entries = @tournament.tournament_entries.registered.includes(agent: :ratings).to_a
    sorted = entries.sort_by do |entry|
      rating = entry.agent.ratings.find { |r| r.game_key == @tournament.game_key }&.current || 1200
      [ -rating, entry.agent_id ]
    end

    sorted.each_with_index do |entry, idx|
      entry.update!(seed: idx + 1)
    end

    sorted
  end
end
