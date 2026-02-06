require "test_helper"

class TournamentRoundRobinSchedulerServiceTest < ActiveSupport::TestCase
  test "produces each unique pairing exactly once" do
    a1 = Agent.create!(name: "RRS1")
    a2 = Agent.create!(name: "RRS2")
    a3 = Agent.create!(name: "RRS3")
    a4 = Agent.create!(name: "RRS4")

    rounds = TournamentRoundRobinSchedulerService.new([ a1, a2, a3, a4 ]).call

    assert_equal 3, rounds.length

    pair_keys = rounds.flat_map do |round|
      round.pairings.map { |p| [ p.agent_a.id, p.agent_b.id ].sort.join(":") }
    end

    assert_equal 6, pair_keys.length
    assert_equal pair_keys.length, pair_keys.uniq.length
  end
end
