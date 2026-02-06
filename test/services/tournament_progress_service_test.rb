require "test_helper"

class TournamentProgressServiceTest < ActiveSupport::TestCase
  test "draw resolves by higher seed and advances tournament" do
    tournament = Tournament.create!(
      name: "Finals",
      status: "running",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    a1 = Agent.create!(name: "P1")
    a2 = Agent.create!(name: "P2")

    TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered", seed: 1)
    TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered", seed: 2)

    round = tournament.tournament_rounds.create!(round_number: 1, status: "running")
    pairing = tournament.tournament_pairings.create!(
      tournament_round: round,
      tournament: tournament,
      slot: 1,
      agent_a: a1,
      agent_b: a2,
      status: "running",
      bye: false
    )
    match = Match.create!(
      tournament: tournament,
      tournament_pairing: pairing,
      game_key: "chess",
      time_control: "rapid",
      rated: true,
      agent_a: a1,
      agent_b: a2,
      status: "finished",
      result: "1/2-1/2"
    )

    TournamentProgressService.new(match).call

    pairing.reload
    round.reload
    tournament.reload

    assert_equal "finished", pairing.status
    assert_equal a1.id, pairing.winner_agent_id
    assert_equal "finished", round.status
    assert_equal "finished", tournament.status
  end
end
