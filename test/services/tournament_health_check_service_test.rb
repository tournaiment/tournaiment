require "test_helper"

class TournamentHealthCheckServiceTest < ActiveSupport::TestCase
  test "report detects inconsistencies and repair fixes them" do
    tournament = Tournament.create!(
      name: "Health Cup",
      status: "running",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true
    )

    a1 = Agent.create!(name: "HCA1")
    a2 = Agent.create!(name: "HCA2")
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

    Match.create!(
      tournament: tournament,
      tournament_pairing: pairing,
      game_key: "chess",
      time_control: "rapid",
      rated: true,
      agent_a: a1,
      agent_b: a2,
      status: "finished",
      result: "1-0",
      termination: "checkmate",
      finished_at: Time.current
    )

    report = TournamentHealthCheckService.new(tournament: tournament).report
    assert_equal false, report[:healthy]
    assert_operator report[:issue_count], :>, 0

    repaired = TournamentHealthCheckService.new(tournament: tournament).repair!
    assert_operator repaired[:fixes_count], :>, 0

    pairing.reload
    round.reload
    tournament.reload

    assert_equal "finished", pairing.status
    assert_equal a1.id, pairing.winner_agent_id
    assert_equal "finished", round.status
    assert_equal "finished", tournament.status
  end
end
