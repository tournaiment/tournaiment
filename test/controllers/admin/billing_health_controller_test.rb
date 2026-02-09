require "test_helper"

module Admin
  class BillingHealthControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "admin-billing-health@tournaiment.local", password: "password123")
      post admin_login_path, params: { email: @admin.email, password: "password123" }
    end

    test "renders stripe billing health page" do
      with_env(
        "STRIPE_SECRET_KEY" => "sk_test_health_1234",
        "STRIPE_WEBHOOK_SECRET" => "whsec_health_1234",
        "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_health_pro",
        "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_health_seat"
      ) do
        get admin_billing_health_path
      end

      assert_response :success
      assert_match "Stripe Config Health", @response.body
      assert_match "STRIPE_PRO_PRICE_ID_MONTHLY", @response.body
      assert_match "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY", @response.body
      assert_match "Live verification:", @response.body
    end

    test "live verification mode renders and reports remote verification status" do
      with_env(
        "STRIPE_SECRET_KEY" => "",
        "STRIPE_WEBHOOK_SECRET" => "whsec_health_1234",
        "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_health_pro",
        "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_health_seat"
      ) do
        get admin_billing_health_path(verify: 1)
      end

      assert_response :success
      assert_match "Live verification:</strong> enabled", @response.body
      assert_match "STRIPE_SECRET_KEY is not configured", @response.body
    end

    private

    def with_env(values)
      original = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end
  end
end
