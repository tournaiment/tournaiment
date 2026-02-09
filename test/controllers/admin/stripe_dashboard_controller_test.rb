require "test_helper"

module Admin
  class StripeDashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "admin-stripe-dashboard@tournaiment.local", password: "password123")
      post admin_login_path, params: { email: @admin.email, password: "password123" }
    end

    test "renders stripe dashboard page" do
      get admin_stripe_dashboard_path

      assert_response :success
      assert_match "Stripe Dashboard", @response.body
      assert_match "Local", @response.body
      assert_match "Dev", @response.body
      assert_match "Prod", @response.body
    end
  end
end
