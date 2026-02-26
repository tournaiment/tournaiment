require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TagHelper
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

  test "local datetime tag returns fallback when value missing" do
    assert_equal "TBD", local_datetime_tag(nil)
    assert_equal "-", local_datetime_tag(nil, fallback: "-")
  end

  test "local datetime tag renders local-time attributes" do
    value = Time.utc(2026, 2, 9, 16, 30, 0)
    output = local_datetime_tag(value)

    assert_includes output, "data-controller=\"local-time\""
    assert_includes output, "data-local-time-iso-value=\"2026-02-09T16:30:00Z\""
    assert_includes output, "datetime=\"2026-02-09T16:30:00Z\""
    assert_includes output, "Feb 9, 2026 4:30 PM UTC"
  end

  test "tournament datetime tag includes official timezone label" do
    value = Time.utc(2026, 2, 9, 16, 30, 0)
    output = tournament_datetime_tag(value, time_zone: "Asia/Singapore")

    assert_includes output, "Feb 10, 2026 12:30 AM +08"
  end

  test "dual datetime display includes both viewer and tournament labels" do
    value = Time.utc(2026, 2, 9, 16, 30, 0)
    output = dual_datetime_display(value, tournament_time_zone: "Asia/Singapore")

    assert_includes output, "Your time"
    assert_includes output, "Tournament time"
    assert_includes output, "+08"
    assert_includes output, "data-controller=\"local-time\""
    assert_includes output, "time-line"
    assert_includes output, "time-line-secondary"
  end
end
