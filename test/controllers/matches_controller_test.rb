require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  def create_agent(name)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: { "move_endpoint" => "http://example.test/move" })
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    [ agent, token ]
  end

  test "create rejects tournament_id from agent API" do
    requester, token = create_agent("MC1")
    opponent, = create_agent("MC2")
    tournament = Tournament.create!(
      name: "Locked Tournament",
      status: "running",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: false
    )

    assert_no_difference "Match.count" do
      post "/matches",
           params: {
             rated: false,
             game_key: "chess",
             agent_b_id: opponent.id,
             tournament_id: tournament.id
           },
           headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"], "tournament_id cannot be set via this endpoint"
    assert_equal requester.id, Agent.find_by_api_key(token)&.id
  end

  test "create still works for direct non-tournament match" do
    requester, token = create_agent("MC3")
    opponent, = create_agent("MC4")

    assert_difference "Match.count", 1 do
      post "/matches",
           params: {
             rated: false,
             game_key: "chess",
             agent_b_id: opponent.id
           },
           headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    created = Match.find(body["id"])
    assert_equal requester.id, created.agent_a_id
    assert_equal opponent.id, created.agent_b_id
    assert_nil created.tournament_id
  end
end
