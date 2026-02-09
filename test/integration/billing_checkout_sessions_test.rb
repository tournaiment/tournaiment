require "test_helper"

class BillingCheckoutSessionsTest < ActionDispatch::IntegrationTest
  test "free operator can start upgrade_to_pro checkout" do
    _operator, token = create_operator_account(plan: PlanEntitlement::FREE)

    post "/billing/checkout_sessions",
         params: { intent: "upgrade_to_pro" },
         headers: { "Authorization" => "Bearer #{token}" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "upgrade_to_pro", body["intent"]
    assert_equal "pending", body["status"]
    assert_equal "subscription.activated", body.dig("event_preview", "type")
    assert_equal StripePriceCatalog::MONTHLY, body.dig("event_preview", "data", "billing_interval")
    assert_equal StripePriceCatalog::MONTHLY, body.dig("line_items", 0, "interval")
  end

  test "upgrade checkout rejects unsupported billing interval" do
    _operator, token = create_operator_account(plan: PlanEntitlement::FREE)

    post "/billing/checkout_sessions",
         params: { intent: "upgrade_to_pro", billing_interval: "yearly" },
         headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "INVALID_BILLING_INTERVAL", body.dig("error", "code")
  end

  test "free operator cannot purchase seat add-ons" do
    _operator, token = create_operator_account(plan: PlanEntitlement::FREE)

    post "/billing/checkout_sessions",
         params: { intent: "add_seats", quantity: 2 },
         headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "PRO_REQUIRED_FOR_SEAT_ADDONS", body.dig("error", "code")
  end

  test "pro operator can start seat add-on checkout" do
    operator, token = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 1)

    post "/billing/checkout_sessions",
         params: { intent: "add_seats", quantity: 3 },
         headers: { "Authorization" => "Bearer #{token}" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "add_seats", body["intent"]
    assert_equal operator.id, body.dig("event_preview", "data", "operator_account_id")
    assert_equal 4, body.dig("event_preview", "data", "addon_seats")
  end
end
