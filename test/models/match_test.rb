require "test_helper"

class MatchTest < ActiveSupport::TestCase
  def build_agent(name)
    Agent.create!(name: name)
  end

  test "rated match auto-assigns approved preset when omitted" do
    agent_a = build_agent("MTA1")
    agent_b = build_agent("MTA2")

    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: true,
      time_control: "rapid"
    )

    assert match.time_control_preset.present?
    assert_equal "chess", match.time_control_preset.game_key
    assert_equal true, match.time_control_preset.rated_allowed
    assert_equal "rapid", match.time_control_preset.category
  end

  test "rated match rejects unrated preset" do
    agent_a = build_agent("MTR1")
    agent_b = build_agent("MTR2")
    unrated = TimeControlPreset.create!(
      key: "test_chess_blitz_unrated_match",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 0 },
      rated_allowed: false
    )

    match = Match.new(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: true,
      time_control: "blitz",
      time_control_preset: unrated
    )

    assert_not match.valid?
    assert_includes match.errors[:time_control_preset_id], "is not approved for rated games"
  end

  test "rated match requires preset when no approved preset exists for category" do
    agent_a = build_agent("MTP1")
    agent_b = build_agent("MTP2")

    match = Match.new(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: true,
      time_control: "classical"
    )

    assert_not match.valid?
    assert_includes match.errors[:time_control_preset_id], "is required for rated matches"
  end

  test "stale transition cannot overwrite a newer terminal status" do
    agent_a = build_agent("MTS1")
    agent_b = build_agent("MTS2")

    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: false,
      status: "running"
    )
    stale = Match.find(match.id)

    match.update!(status: "cancelled")
    assert_equal false, stale.finish!
    assert_equal "cancelled", match.reload.status
  end

  test "record_move returns terminal result without persisting while match is running" do
    agent_a = build_agent("MTG1")
    agent_b = build_agent("MTG2")
    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "go",
      rated: false,
      status: "running"
    )

    first = match.record_move!("pass")
    second = match.record_move!("pass")

    assert_nil first[:result]
    assert second[:result].present?
    assert_nil match.reload.result
    assert_equal "running", match.status
  end
end
