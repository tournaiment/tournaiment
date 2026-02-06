require "test_helper"

class MatchRequestTest < ActiveSupport::TestCase
  def build_agent(name)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: { "move_endpoint" => "http://example.test/move" })
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    agent
  end

  test "challenge requires opponent" do
    agent = build_agent("A1")
    preset = TimeControlPreset.create!(
      key: "chess_blitz_test_1",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true
    )

    request = MatchRequest.new(
      requester_agent: agent,
      request_type: "challenge",
      game_key: "chess",
      rated: true,
      time_control_preset: preset
    )

    assert_not request.valid?
    assert_includes request.errors[:opponent_agent_id], "is required for challenge requests"
  end

  test "rated request rejects unrated preset" do
    agent = build_agent("A2")
    opponent = build_agent("A3")
    preset = TimeControlPreset.create!(
      key: "go_blitz_test_1",
      game_key: "go",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 300, increment_seconds: 3 },
      rated_allowed: false
    )

    request = MatchRequest.new(
      requester_agent: agent,
      opponent_agent: opponent,
      request_type: "challenge",
      game_key: "go",
      rated: true,
      time_control_preset: preset
    )

    assert_not request.valid?
    assert_includes request.errors[:time_control_preset_id], "is not approved for rated games"
  end

  test "tournament request enforces tournament preset allowlist" do
    agent = build_agent("A4")
    opponent = build_agent("A5")
    allowed = TimeControlPreset.create!(
      key: "chess_blitz_allowed_test",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true
    )
    blocked = TimeControlPreset.create!(
      key: "chess_rapid_blocked_test",
      game_key: "chess",
      category: "rapid",
      clock_type: "increment",
      clock_config: { base_seconds: 600, increment_seconds: 0 },
      rated_allowed: true
    )
    tournament = Tournament.create!(name: "Preset Cup", status: "running", time_control: "rapid", format: "single_elimination", game_key: "chess", rated: true)
    TournamentTimeControlPreset.create!(tournament: tournament, time_control_preset: allowed)

    request = MatchRequest.new(
      requester_agent: agent,
      opponent_agent: opponent,
      request_type: "challenge",
      game_key: "chess",
      rated: true,
      tournament: tournament,
      time_control_preset: blocked
    )

    assert_not request.valid?
    assert_includes request.errors[:time_control_preset_id], "is not allowed for this tournament"
  end

  test "tournament request enforces locked preset" do
    agent = build_agent("A6")
    opponent = build_agent("A7")
    locked = TimeControlPreset.create!(
      key: "go_locked_test",
      game_key: "go",
      category: "rapid",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
      rated_allowed: true
    )
    other = TimeControlPreset.create!(
      key: "go_other_test",
      game_key: "go",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 300, increment_seconds: 3 },
      rated_allowed: false
    )
    tournament = Tournament.create!(name: "Locked Go Cup", status: "running", time_control: "rapid", format: "single_elimination", game_key: "go", rated: false, locked_time_control_preset: locked)

    request = MatchRequest.new(
      requester_agent: agent,
      opponent_agent: opponent,
      request_type: "challenge",
      game_key: "go",
      rated: false,
      tournament: tournament,
      time_control_preset: other
    )

    assert_not request.valid?
    assert_includes request.errors[:time_control_preset_id], "is not allowed for this tournament"
  end
end
