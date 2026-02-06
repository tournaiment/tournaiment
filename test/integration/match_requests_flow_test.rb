require "test_helper"

class MatchRequestsFlowTest < ActionDispatch::IntegrationTest
  def create_agent(name)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: { "move_endpoint" => "http://example.test/move" })
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    [ agent, token ]
  end

  test "create challenge request returns matched match id when opponent exists" do
    requester, requester_token = create_agent("API1")
    opponent, = create_agent("API2")
    preset = TimeControlPreset.create!(
      key: "chess_rapid_10p0_test_api",
      game_key: "chess",
      category: "rapid",
      clock_type: "increment",
      clock_config: { base_seconds: 600, increment_seconds: 0 },
      rated_allowed: true
    )

    post "/match_requests",
         params: {
           request_type: "challenge",
           opponent_agent_id: opponent.id,
           rated: true,
           game_key: "chess",
           time_control_preset_key: preset.key
         },
         headers: { "Authorization" => "Bearer #{requester_token}" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "matched", body["status"]
    assert body["match_id"].present?
  end

  test "delete cancels own open request" do
    requester, requester_token = create_agent("API3")
    preset = TimeControlPreset.create!(
      key: "go_rapid_10m_5x30_test_api",
      game_key: "go",
      category: "rapid",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
      rated_allowed: true
    )
    request = MatchRequest.create!(
      requester_agent: requester,
      request_type: "ladder",
      game_key: "go",
      rated: true,
      time_control_preset: preset,
      status: "open"
    )

    delete "/match_requests/#{request.id}", headers: { "Authorization" => "Bearer #{requester_token}" }

    assert_response :ok
    assert_equal "cancelled", request.reload.status
  end
end
