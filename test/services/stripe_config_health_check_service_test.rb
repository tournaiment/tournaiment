require "test_helper"

class StripeConfigHealthCheckServiceTest < ActiveSupport::TestCase
  test "reports errors when required billing env values are missing" do
    env = {}
    report = StripeConfigHealthCheckService.new(env:, verify_remote: false, rails_env: "development").call

    assert_equal :error, report[:overall_status]
    assert report.dig(:counts, :error) >= 3
    labels = report[:checks].map { |check| check[:label] }
    assert_includes labels, "STRIPE_SECRET_KEY"
    assert_includes labels, "STRIPE_PRO_PRICE_ID_MONTHLY"
    assert_includes labels, "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY"
  end

  test "passes local config and validates remote monthly prices with stubbed client" do
    env = {
      "STRIPE_SECRET_KEY" => "sk_test_1234567890",
      "STRIPE_WEBHOOK_SECRET" => "whsec_1234567890",
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_monthly",
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_monthly",
      "BILLING_PAST_DUE_GRACE_DAYS" => "7"
    }

    fake_client = Class.new do
      def retrieve_price(price_id)
        {
          "id" => price_id,
          "object" => "price",
          "active" => true,
          "type" => "recurring",
          "recurring" => { "interval" => "month" }
        }
      end
    end.new

    report = StripeConfigHealthCheckService.new(
      env:,
      verify_remote: true,
      rails_env: "development",
      stripe_client: fake_client
    ).call

    assert_equal :ok, report[:overall_status]
    assert_equal 0, report.dig(:counts, :error)
  end

  test "remote verification fails when stripe price is not monthly recurring" do
    env = {
      "STRIPE_SECRET_KEY" => "sk_test_1234567890",
      "STRIPE_WEBHOOK_SECRET" => "whsec_1234567890",
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_monthly",
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_monthly",
      "BILLING_PAST_DUE_GRACE_DAYS" => "7"
    }

    fake_client = Class.new do
      def retrieve_price(price_id)
        {
          "id" => price_id,
          "object" => "price",
          "active" => true,
          "type" => "recurring",
          "recurring" => { "interval" => "year" }
        }
      end
    end.new

    report = StripeConfigHealthCheckService.new(
      env:,
      verify_remote: true,
      rails_env: "development",
      stripe_client: fake_client
    ).call

    assert_equal :error, report[:overall_status]
    assert report.dig(:counts, :error).positive?
  end
end
