require "test_helper"

module Admin
  class OperatorAccountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "admin-operators@tournaiment.local", password: "password123")
      post admin_login_path, params: { email: @admin.email, password: "password123" }
    end

    test "index and show render entitlement and seat status" do
      operator, = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2)
      active_agent, = create_agent_for_operator(operator_account: operator, name: "AOP1")
      suspended_agent, = create_agent_for_operator(operator_account: operator, name: "AOP2")
      suspended_agent.update!(status: "suspended_no_seat")

      get admin_operator_accounts_path
      assert_response :success
      assert_match operator.email, @response.body
      assert_match "3", @response.body

      get admin_operator_account_path(operator)
      assert_response :success
      assert_match active_agent.name, @response.body
      assert_match suspended_agent.name, @response.body
      assert_match "suspended_no_seat", @response.body
    end

    test "reallocate seats enforces deterministic active set" do
      operator, = create_operator_account(plan: PlanEntitlement::FREE)
      first, = create_agent_for_operator(operator_account: operator, name: "AOP3")
      second, = create_agent_for_operator(operator_account: operator, name: "AOP4")
      first.update!(status: "suspended_no_seat")
      second.update!(status: "active")

      post reallocate_seats_admin_operator_account_path(operator)

      assert_redirected_to admin_operator_account_path(operator)
      assert_equal "active", first.reload.status
      assert_equal "suspended_no_seat", second.reload.status
    end
  end
end
