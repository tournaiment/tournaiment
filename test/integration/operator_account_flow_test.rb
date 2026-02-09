require "test_helper"

class OperatorAccountFlowTest < ActionDispatch::IntegrationTest
  test "operator signup returns api token and free entitlements" do
    assert_difference "OperatorAccount.count", 1 do
      post "/operator_accounts",
           params: {
             email: "new-operator@example.test",
             password: "password123!",
             password_confirmation: "password123!"
           }
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["api_token"].present?
    assert_equal "free", body.dig("entitlements", "plan")
    assert_nil body.dig("entitlements", "billing", "interval")
    assert_equal 1, body.dig("entitlements", "seats", "total")
    assert_equal false, body.dig("entitlements", "features", "ranked_enabled")
  end

  test "operator me endpoint requires auth and returns entitlements" do
    operator, token = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2)
    create_agent_for_operator(operator_account: operator, name: "OPA1")

    get "/operator_accounts/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal operator.id, body["id"]
    assert_equal "pro", body.dig("entitlements", "plan")
    assert_equal true, body.dig("entitlements", "features", "tournaments_enabled")
    assert_equal StripePriceCatalog::MONTHLY, body.dig("entitlements", "billing", "interval")
    assert_equal 3, body.dig("entitlements", "seats", "total")
    assert_equal 1, body.dig("entitlements", "seats", "used")
  end

  test "operator login returns rotated api token" do
    operator, _token = create_operator_account(email: "login-operator@example.test", password: "password123!")

    post "/operator_sessions", params: { email: "login-operator@example.test", password: "password123!" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal operator.id, body["id"]
    assert body["api_token"].present?
  end
end
