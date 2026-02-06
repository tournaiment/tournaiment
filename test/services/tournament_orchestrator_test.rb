require "test_helper"

class TournamentOrchestratorTest < ActiveSupport::TestCase
  test "start creates seeded round pairings and queued matches" do
    tournament = Tournament.create!(
      name: "Spring Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    a1 = Agent.create!(name: "A1")
    a2 = Agent.create!(name: "A2")
    a3 = Agent.create!(name: "A3")

    Rating.find_by!(agent: a1, game_key: "chess").update!(current: 1400)
    Rating.find_by!(agent: a2, game_key: "chess").update!(current: 1300)
    Rating.find_by!(agent: a3, game_key: "chess").update!(current: 1200)

    TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered")
    TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered")
    TournamentEntry.create!(tournament: tournament, agent: a3, status: "registered")

    TournamentOrchestrator.new(tournament).start!

    tournament.reload
    assert_equal "running", tournament.status

    round = tournament.tournament_rounds.find_by!(round_number: 1)
    assert_equal "running", round.status
    assert_equal 2, round.tournament_pairings.count

    seeds = tournament.tournament_entries.order(:seed).pluck(:agent_id)
    assert_equal [ a1.id, a2.id, a3.id ], seeds

    active_pairings = round.tournament_pairings.where(bye: false)
    assert_equal 1, active_pairings.count
    pairing = active_pairings.first
    assert_equal "running", pairing.status
    assert pairing.match.present?
    assert_equal "queued", pairing.match.status

    bye_pairing = round.tournament_pairings.find_by!(bye: true)
    assert_equal "finished", bye_pairing.status
    assert_equal bye_pairing.agent_a_id, bye_pairing.winner_agent_id
  end
end
