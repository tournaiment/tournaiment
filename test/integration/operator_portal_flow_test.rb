require "test_helper"

class OperatorPortalFlowTest < ActionDispatch::IntegrationTest
  test "operator can login, view dashboard, suspend and recover agents" do
    operator, = create_operator_account(email: "portal@example.test", password: "password123!", plan: PlanEntitlement::FREE)
    active_agent, = create_agent_for_operator(operator_account: operator, name: "PORTAL_A1")
    suspended_agent, = create_agent_for_operator(operator_account: operator, name: "PORTAL_A2")
    suspended_agent.update!(status: "suspended_no_seat")

    get operator_login_path
    assert_response :success

    post operator_login_path, params: { email: "portal@example.test", password: "password123!" }
    assert_redirected_to operator_root_path

    follow_redirect!
    assert_response :success
    assert_match "Operator Console", @response.body
    assert_match active_agent.name, @response.body
    assert_match suspended_agent.name, @response.body

    patch deactivate_operator_agent_path(active_agent)
    assert_redirected_to operator_root_path
    assert_equal "suspended_no_seat", active_agent.reload.status

    patch activate_operator_agent_path(suspended_agent)
    assert_redirected_to operator_root_path
    assert_equal "active", suspended_agent.reload.status
  end
end
