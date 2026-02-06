require "test_helper"

class MatchClockTest < ActiveSupport::TestCase
  def create_agent(name)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: { "move_endpoint" => "http://example.test/move" })
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    agent
  end

  test "increment clock initializes and applies increment" do
    a = create_agent("C1")
    b = create_agent("C2")
    preset = TimeControlPreset.create!(
      key: "chess_blitz_clock_test",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true
    )
    match = Match.create!(agent_a: a, agent_b: b, game_key: "chess", status: "created", time_control_preset: preset)
    clock = MatchClock.new(match)

    clock.ensure_initialized!
    match.reload
    assert_equal "increment", match.clock_state["clock_type"]
    assert_in_delta 180.0, match.clock_state.dig("remaining_seconds", "white"), 0.0001

    assert_equal :ok, clock.consume!("white", 5.0)
    match.reload
    assert_in_delta 177.0, match.clock_state.dig("remaining_seconds", "white"), 0.0001
  end

  test "increment clock flags time loss when elapsed exceeds remaining" do
    a = create_agent("C3")
    b = create_agent("C4")
    preset = TimeControlPreset.create!(
      key: "chess_bullet_clock_test",
      game_key: "chess",
      category: "bullet",
      clock_type: "increment",
      clock_config: { base_seconds: 1, increment_seconds: 0 },
      rated_allowed: true
    )
    match = Match.create!(agent_a: a, agent_b: b, game_key: "chess", status: "created", time_control_preset: preset)
    clock = MatchClock.new(match)

    clock.ensure_initialized!
    assert_equal :time_loss, clock.consume!("white", 2.0)
  end

  test "byoyomi uses main time before periods" do
    a = create_agent("C5")
    b = create_agent("C6")
    preset = TimeControlPreset.create!(
      key: "go_rapid_clock_test",
      game_key: "go",
      category: "rapid",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 10, period_time_seconds: 5, periods: 3 },
      rated_allowed: true
    )
    match = Match.create!(agent_a: a, agent_b: b, game_key: "go", status: "created", time_control_preset: preset)
    clock = MatchClock.new(match)

    clock.ensure_initialized!
    assert_equal :ok, clock.consume!("black", 4.0)
    match.reload
    assert_in_delta 6.0, match.clock_state.dig("main_time_seconds", "black"), 0.0001
    assert_equal 3, match.clock_state.dig("periods_left", "black")
  end

  test "byoyomi consumes periods and can time out" do
    a = create_agent("C7")
    b = create_agent("C8")
    preset = TimeControlPreset.create!(
      key: "go_blitz_clock_test",
      game_key: "go",
      category: "blitz",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 0, period_time_seconds: 5, periods: 2 },
      rated_allowed: true
    )
    match = Match.create!(agent_a: a, agent_b: b, game_key: "go", status: "created", time_control_preset: preset)
    clock = MatchClock.new(match)

    clock.ensure_initialized!
    assert_equal :ok, clock.consume!("black", 7.0)
    match.reload
    assert_equal 1, match.clock_state.dig("periods_left", "black")

    assert_equal :time_loss, clock.consume!("black", 7.0)
  end
end
