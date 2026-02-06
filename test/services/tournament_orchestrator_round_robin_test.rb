require "test_helper"

class TournamentOrchestratorRoundRobinTest < ActiveSupport::TestCase
  test "start creates all rounds and queues only first round matches" do
    tournament = Tournament.create!(
      name: "RR Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "round_robin",
      game_key: "chess"
    )

    a1 = Agent.create!(name: "RRA1")
    a2 = Agent.create!(name: "RRA2")
    a3 = Agent.create!(name: "RRA3")
    a4 = Agent.create!(name: "RRA4")

    TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered")
    TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered")
    TournamentEntry.create!(tournament: tournament, agent: a3, status: "registered")
    TournamentEntry.create!(tournament: tournament, agent: a4, status: "registered")

    TournamentOrchestrator.new(tournament).start!

    tournament.reload
    assert_equal "running", tournament.status
    assert_equal 3, tournament.tournament_rounds.count

    round1 = tournament.tournament_rounds.find_by!(round_number: 1)
    round2 = tournament.tournament_rounds.find_by!(round_number: 2)

    assert_equal "running", round1.status
    assert_equal "pending", round2.status

    assert_equal 2, round1.tournament_pairings.count
    assert_equal 2, round2.tournament_pairings.count

    assert_equal [ "queued" ], round1.tournament_pairings.includes(:match).map { |p| p.match.status }.uniq
    assert_equal [ "created" ], round2.tournament_pairings.includes(:match).map { |p| p.match.status }.uniq
  end

  test "advance starts next round and finishes tournament at end" do
    tournament = Tournament.create!(
      name: "RR Flow",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "round_robin",
      game_key: "chess"
    )

    agents = %w[RRF1 RRF2 RRF3 RRF4].map { |name| Agent.create!(name: name) }
    agents.each { |agent| TournamentEntry.create!(tournament: tournament, agent: agent, status: "registered") }

    orchestrator = TournamentOrchestrator.new(tournament)
    orchestrator.start!

    round1 = tournament.tournament_rounds.find_by!(round_number: 1)
    round1.tournament_pairings.includes(:match).each do |pairing|
      pairing.match.update!(status: "finished", result: "1-0")
      pairing.update!(winner_agent: pairing.agent_a, status: "finished")
    end

    orchestrator.advance_if_ready!(round1)

    round2 = tournament.tournament_rounds.find_by!(round_number: 2)
    round2.reload
    assert_equal "running", round2.status
    assert_equal [ "queued" ], round2.tournament_pairings.includes(:match).map { |p| p.match.status }.uniq

    round2.tournament_pairings.includes(:match).each do |pairing|
      pairing.match.update!(status: "finished", result: "1-0")
      pairing.update!(winner_agent: pairing.agent_a, status: "finished")
    end
    orchestrator.advance_if_ready!(round2)

    round3 = tournament.tournament_rounds.find_by!(round_number: 3)
    round3.tournament_pairings.includes(:match).each do |pairing|
      pairing.match.update!(status: "finished", result: "1-0")
      pairing.update!(winner_agent: pairing.agent_a, status: "finished")
    end
    orchestrator.advance_if_ready!(round3)

    tournament.reload
    assert_equal "finished", tournament.status
  end
end
