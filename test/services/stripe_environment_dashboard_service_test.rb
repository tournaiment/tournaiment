require "test_helper"
require "tmpdir"

class StripeEnvironmentDashboardServiceTest < ActiveSupport::TestCase
  test "builds local dev prod profiles from env files" do
    Dir.mktmpdir("stripe-dashboard") do |tmpdir|
      root = Pathname.new(tmpdir)
      write_env_file(root.join(".env.local"), <<~ENV)
        STRIPE_SECRET_KEY=sk_test_local
        STRIPE_WEBHOOK_SECRET=whsec_local
        STRIPE_PRO_PRICE_ID_MONTHLY=price_local_pro
        STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY=price_local_seat
        BILLING_PAST_DUE_GRACE_DAYS=7
      ENV
      write_env_file(root.join(".env.prod"), <<~ENV)
        STRIPE_SECRET_KEY=sk_live_prod
        STRIPE_WEBHOOK_SECRET=whsec_prod
        STRIPE_PRO_PRICE_ID_MONTHLY=price_prod_pro
        STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY=price_prod_seat
      ENV

      dashboard = StripeEnvironmentDashboardService.new(root: root, verify_remote: false, env: {}).call
      assert_equal 3, dashboard[:profiles].size

      local = dashboard[:profiles].find { |profile| profile[:id] == "local" }
      dev = dashboard[:profiles].find { |profile| profile[:id] == "dev" }
      prod = dashboard[:profiles].find { |profile| profile[:id] == "prod" }

      assert local[:file_exists]
      assert_equal :ok, local.dig(:report, :overall_status)
      assert_equal false, dev[:file_exists]
      assert_equal :error, dev.dig(:report, :overall_status)
      assert prod[:file_exists]
    end
  end

  test "supports dashboard url overrides per profile" do
    dashboard = StripeEnvironmentDashboardService.new(
      verify_remote: false,
      env: {
        "STRIPE_DASHBOARD_URL_LOCAL" => "https://stripe.local.example",
        "STRIPE_DASHBOARD_URL_DEV" => "https://stripe.dev.example",
        "STRIPE_DASHBOARD_URL_PROD" => "https://stripe.prod.example"
      }
    ).call

    assert_equal "https://stripe.local.example", dashboard[:profiles].find { |profile| profile[:id] == "local" }[:dashboard_url]
    assert_equal "https://stripe.dev.example", dashboard[:profiles].find { |profile| profile[:id] == "dev" }[:dashboard_url]
    assert_equal "https://stripe.prod.example", dashboard[:profiles].find { |profile| profile[:id] == "prod" }[:dashboard_url]
  end

  private

  def write_env_file(path, content)
    path.dirname.mkpath
    path.write(content)
  end
end
