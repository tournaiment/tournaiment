require "test_helper"

class TournamentNotifyAgentsJobTest < ActiveJob::TestCase
  test "fanouts per agent for retries" do
    tournament = Tournament.create!(
      name: "Notify Cup",
      status: "running",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true
    )
    a1 = Agent.create!(name: "NJA1")
    a2 = Agent.create!(name: "NJA2")

    assert_enqueued_jobs 2 do
      TournamentNotifyAgentsJob.perform_now(
        tournament_id: tournament.id,
        event: "match_assigned",
        agent_ids: [ a1.id, a2.id ],
        payload: { match_id: "m1" }
      )
    end
  end

  test "single agent uses notification service in strict mode" do
    tournament = Tournament.create!(
      name: "Notify Cup 2",
      status: "running",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true
    )
    agent = Agent.create!(name: "NJS1")

    captured = {}
    fake_service = Object.new
    fake_service.define_singleton_method(:call) { true }

    service_singleton = class << TournamentNotificationService; self; end
    original_new = TournamentNotificationService.method(:new)
    service_singleton.define_method(:new) do |**kwargs|
      captured.merge!(kwargs)
      fake_service
    end

    TournamentNotifyAgentsJob.perform_now(
      tournament_id: tournament.id,
      event: "tournament_started",
      agent_ids: [ agent.id ],
      payload: { round: 1 }
    )

    assert_equal true, captured[:raise_on_failure]
    assert_equal [ agent.id ], captured[:agent_ids]
  ensure
    service_singleton.define_method(:new, original_new)
  end
end
