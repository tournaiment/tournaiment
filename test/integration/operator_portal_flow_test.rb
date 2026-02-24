require "test_helper"

class OperatorPortalFlowTest < ActionDispatch::IntegrationTest
  test "operator can verify email, login with OTP, view dashboard, suspend and recover agents" do
    operator, = create_operator_account(email: "portal@example.test", plan: PlanEntitlement::FREE, verified: false)
    active_agent, = create_agent_for_operator(operator_account: operator, name: "PORTAL_A1")
    suspended_agent, = create_agent_for_operator(operator_account: operator, name: "PORTAL_A2")
    suspended_agent.update!(status: "suspended_no_seat")

    get operator_login_path
    assert_response :success

    verification_code = OperatorOtpService.new.issue!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_EMAIL_VERIFICATION,
      code: "123456"
    )
    assert_equal "123456", verification_code

    post operator_login_path, params: { intent: "submit_code", email: "portal@example.test", otp: "123456" }
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

  test "verified operator can request and submit a login code" do
    operator, = create_operator_account(email: "portal-verified@example.test", plan: PlanEntitlement::FREE, verified: true)

    get operator_login_path
    assert_response :success

    post operator_login_path, params: { intent: "request_code", email: operator.email }
    assert_redirected_to operator_login_path(email: operator.email)

    login_code = OperatorOtpService.new.issue!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "654321"
    )
    assert_equal "654321", login_code

    post operator_login_path, params: { intent: "submit_code", email: operator.email, otp: "654321" }
    assert_redirected_to operator_root_path
  end
end
