require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper

  test "result label prefers winner_side over legacy result mapping" do
    agent_a = Agent.create!(name: "HLP1")
    agent_b = Agent.create!(name: "HLP2")
    preset = TimeControlPreset.find_by!(key: "test_go_rapid_10m_5x30")

    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "go",
      rated: true,
      status: "finished",
      result: "0-1",
      winner_side: "a",
      time_control: preset.category,
      time_control_preset: preset
    )

    assert_equal "#{agent_a.name} wins", match_result_label(match)
    assert_equal :win, match_outcome_for_agent(match, agent_a)
    assert_equal :loss, match_outcome_for_agent(match, agent_b)
  end
end
