require "openssl"
require "test_helper"

class StripeWebhooksFlowTest < ActionDispatch::IntegrationTest
  test "subscription updated event maps to internal billing payload with idempotency" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)
    with_stripe_env(
      "STRIPE_WEBHOOK_SECRET" => "whsec_test_local",
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_123",
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_123"
    ) do
      payload = {
        id: "evt_stripe_sub_1",
        type: "customer.subscription.updated",
        data: {
          object: {
            id: "sub_123",
            customer: "cus_123",
            status: "active",
            current_period_end: Time.current.to_i + 1.day.to_i,
            metadata: { operator_account_id: operator.id },
            items: {
              data: [
                { price: { id: "price_pro_123" }, quantity: 1 },
                { price: { id: "price_seat_123" }, quantity: 4 }
              ]
            }
          }
        }
      }

      post_signed_stripe_webhook(payload, secret: "whsec_test_local")
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal false, body["duplicate"]

      entitlement = operator.reload.entitlement
      assert_equal PlanEntitlement::PRO, entitlement.plan
      assert_equal 4, entitlement.addon_seats
      assert_equal StripePriceCatalog::MONTHLY, entitlement.billing_interval
      assert_equal "active", entitlement.subscription_status
      assert_equal "cus_123", operator.stripe_customer_id
      assert_equal "sub_123", operator.stripe_subscription_id

      post_signed_stripe_webhook(payload, secret: "whsec_test_local")
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal true, body["duplicate"]
    end
  end

  test "invalid stripe signature is rejected when secret is configured" do
    with_stripe_env("STRIPE_WEBHOOK_SECRET" => "whsec_test_local") do
      payload = { id: "evt_invalid_sig", type: "customer.subscription.updated", data: { object: {} } }
      post "/billing/stripe_webhooks",
           params: payload.to_json,
           headers: {
             "Content-Type" => "application/json",
             "Stripe-Signature" => "t=#{Time.current.to_i},v1=bad-signature"
           }

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_equal "INVALID_STRIPE_SIGNATURE", body.dig("error", "code")
    end
  end

  test "unsupported interval metadata falls back to monthly" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)
    with_stripe_env(
      "STRIPE_WEBHOOK_SECRET" => "whsec_test_local",
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_monthly",
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_monthly"
    ) do
      payload = {
        id: "evt_stripe_monthly_fallback_1",
        type: "customer.subscription.updated",
        data: {
          object: {
            id: "sub_monthly_fallback_1",
            customer: "cus_monthly_fallback_1",
            status: "active",
            metadata: { operator_account_id: operator.id, billing_interval: "yearly" },
            items: {
              data: [
                { price: { id: "price_pro_monthly" }, quantity: 1 },
                { price: { id: "price_seat_monthly" }, quantity: 2 }
              ]
            }
          }
        }
      }

      post_signed_stripe_webhook(payload, secret: "whsec_test_local")
      assert_response :ok

      entitlement = operator.reload.entitlement
      assert_equal StripePriceCatalog::MONTHLY, entitlement.billing_interval
      assert_equal 2, entitlement.addon_seats
    end
  end

  private

  def post_signed_stripe_webhook(payload, secret:)
    body = payload.to_json
    timestamp = Time.current.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")

    post "/billing/stripe_webhooks",
         params: body,
         headers: {
           "Content-Type" => "application/json",
           "Stripe-Signature" => "t=#{timestamp},v1=#{signature}"
         }
  end

  def with_stripe_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
