require "test_helper"

class MatchRequestMatcherTest < ActiveSupport::TestCase
  def create_agent(name)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: { "move_endpoint" => "http://example.test/move" })
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    agent
  end

  def create_preset(key: "chess_blitz_3p2_test")
    TimeControlPreset.create!(
      key: key,
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true
    )
  end

  test "challenge request creates queued match and marks matched" do
    a = create_agent("M1")
    b = create_agent("M2")
    preset = create_preset

    request = MatchRequest.create!(
      requester_agent: a,
      opponent_agent: b,
      request_type: "challenge",
      status: "open",
      game_key: "chess",
      rated: true,
      time_control_preset: preset
    )

    MatchRequestMatcher.new(request).process!
    request.reload

    assert_equal "matched", request.status
    assert request.match_id.present?

    match = request.match
    assert_equal "queued", match.status
    assert_equal a.id, match.agent_a_id
    assert_equal b.id, match.agent_b_id
    assert_equal preset.id, match.time_control_preset_id
  end

  test "ladder requests match deterministically by oldest open request" do
    a = create_agent("L1")
    b = create_agent("L2")
    preset = create_preset(key: "chess_blitz_3p2_test_ladder")

    older = MatchRequest.create!(
      requester_agent: a,
      request_type: "ladder",
      status: "open",
      game_key: "chess",
      rated: false,
      time_control_preset: preset
    )
    sleep 0.01
    newer = MatchRequest.create!(
      requester_agent: b,
      request_type: "ladder",
      status: "open",
      game_key: "chess",
      rated: false,
      time_control_preset: preset
    )

    MatchRequestMatcher.new(newer).process!
    older.reload
    newer.reload

    assert_equal "matched", older.status
    assert_equal "matched", newer.status
    assert_equal older.match_id, newer.match_id

    match = older.match
    assert_equal a.id, match.agent_a_id
    assert_equal b.id, match.agent_b_id
  end

  test "tournament request does not match unregistered opponents" do
    a = create_agent("T1")
    b = create_agent("T2")
    preset = create_preset(key: "chess_blitz_3p2_test_tournament")
    tournament = Tournament.create!(name: "Cup", time_control: "rapid", status: "running")
    TournamentEntry.create!(tournament: tournament, agent: a, status: "registered")

    request = MatchRequest.create!(
      requester_agent: a,
      opponent_agent: b,
      request_type: "challenge",
      status: "open",
      game_key: "chess",
      rated: true,
      time_control_preset: preset,
      tournament: tournament
    )

    MatchRequestMatcher.new(request).process!
    request.reload
    assert_equal "open", request.status
    assert_nil request.match_id
  end
end
