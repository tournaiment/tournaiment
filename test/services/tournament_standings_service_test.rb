require "test_helper"

class TournamentStandingsServiceTest < ActiveSupport::TestCase
  test "ignores finished matches that are not tied to tournament pairings" do
    tournament = Tournament.create!(
      name: "Standings Cup",
      status: "running",
      format: "round_robin",
      game_key: "chess",
      time_control: "rapid",
      rated: false
    )

    a1 = Agent.create!(name: "TSS1")
    a2 = Agent.create!(name: "TSS2")
    a3 = Agent.create!(name: "TSS3")
    TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered", seed: 1)
    TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered", seed: 2)
    TournamentEntry.create!(tournament: tournament, agent: a3, status: "registered", seed: 3)

    round = tournament.tournament_rounds.create!(round_number: 1, status: "running")
    pairing = tournament.tournament_pairings.create!(
      tournament_round: round,
      tournament: tournament,
      slot: 1,
      agent_a: a1,
      agent_b: a2,
      status: "finished",
      bye: false,
      winner_agent: a1
    )

    Match.create!(
      tournament: tournament,
      tournament_pairing: pairing,
      game_key: "chess",
      time_control: "rapid",
      rated: false,
      agent_a: a1,
      agent_b: a2,
      status: "finished",
      result: "1-0",
      winner_side: "a",
      termination: "checkmate",
      finished_at: Time.current
    )

    Match.create!(
      tournament: tournament,
      game_key: "chess",
      time_control: "rapid",
      rated: false,
      agent_a: a3,
      agent_b: a1,
      status: "finished",
      result: "1-0",
      winner_side: "a",
      termination: "checkmate",
      finished_at: Time.current
    )

    standings = TournamentStandingsService.new(tournament).call
    points_by_agent_id = standings.index_by { |row| row.agent.id }.transform_values(&:points)

    assert_equal 1.0, points_by_agent_id.fetch(a1.id)
    assert_equal 0.0, points_by_agent_id.fetch(a2.id)
    assert_equal 0.0, points_by_agent_id.fetch(a3.id)
  end
end
