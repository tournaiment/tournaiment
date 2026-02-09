require "test_helper"

class AgentSeatAndPlanGatesTest < ActionDispatch::IntegrationTest
  test "free operator can only create one agent seat" do
    _operator, operator_token = create_operator_account(plan: PlanEntitlement::FREE)

    post "/agents",
         params: {
           name: "SEAT1",
           description: "seat test",
           metadata: { move_endpoint: "http://example.test/move" }
         },
         headers: { "Authorization" => "Bearer #{operator_token}" }
    assert_response :created

    assert_no_difference "Agent.count" do
      post "/agents",
           params: {
             name: "SEAT2",
             description: "seat test",
             metadata: { move_endpoint: "http://example.test/move" }
           },
           headers: { "Authorization" => "Bearer #{operator_token}" }
    end

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "AGENT_SEAT_REQUIRED", body.dig("error", "code")
  end

  test "free agent cannot create rated match but can create unrated match" do
    free_operator, = create_operator_account(plan: PlanEntitlement::FREE)
    free_agent, free_agent_token = create_agent_for_operator(operator_account: free_operator, name: "FREE_MATCH_A")

    opponent_operator, = create_operator_account(plan: PlanEntitlement::PRO)
    opponent, = create_agent_for_operator(operator_account: opponent_operator, name: "FREE_MATCH_B")

    assert_no_difference "Match.count" do
      post "/matches",
           params: {
             game_key: "chess",
             agent_b_id: opponent.id
           },
           headers: { "Authorization" => "Bearer #{free_agent_token}" }
    end
    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "PLAN_REQUIRED_RANKED", body.dig("error", "code")

    assert_difference "Match.count", 1 do
      post "/matches",
           params: {
             rated: false,
             game_key: "chess",
             agent_b_id: opponent.id
           },
           headers: { "Authorization" => "Bearer #{free_agent_token}" }
    end
    assert_response :created
    match = Match.order(:created_at).last
    assert_equal free_agent.id, match.agent_a_id
  end

  test "free agent cannot register tournament but pro agent can" do
    free_operator, = create_operator_account(plan: PlanEntitlement::FREE)
    free_agent, free_token = create_agent_for_operator(operator_account: free_operator, name: "FREE_TOURN")
    pro_operator, = create_operator_account(plan: PlanEntitlement::PRO)
    pro_agent, pro_token = create_agent_for_operator(operator_account: pro_operator, name: "PRO_TOURN")

    tournament = Tournament.create!(
      name: "Plan Gate Tournament",
      status: "registration_open",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true
    )

    assert_equal "active", free_agent.status
    post "/tournaments/#{tournament.id}/register", headers: { "Authorization" => "Bearer #{free_token}" }
    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "PLAN_REQUIRED_TOURNAMENT", body.dig("error", "code")

    post "/tournaments/#{tournament.id}/register", headers: { "Authorization" => "Bearer #{pro_token}" }
    assert_response :ok
    entry = TournamentEntry.find_by!(tournament: tournament, agent: pro_agent)
    assert_equal "registered", entry.status
  end

  test "free agent cannot create rated match request" do
    free_operator, = create_operator_account(plan: PlanEntitlement::FREE)
    free_agent, free_token = create_agent_for_operator(operator_account: free_operator, name: "FREE_REQ_A")
    pro_operator, = create_operator_account(plan: PlanEntitlement::PRO)
    opponent, = create_agent_for_operator(operator_account: pro_operator, name: "FREE_REQ_B")

    preset = TimeControlPreset.find_by!(key: "test_chess_rapid_10p0")

    assert_equal "active", free_agent.status
    assert_no_difference "MatchRequest.count" do
      post "/match_requests",
           params: {
             request_type: "challenge",
             opponent_agent_id: opponent.id,
             rated: true,
             game_key: "chess",
             time_control_preset_key: preset.key
           },
           headers: { "Authorization" => "Bearer #{free_token}" }
    end

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "PLAN_REQUIRED_RANKED", body.dig("error", "code")
  end
end
