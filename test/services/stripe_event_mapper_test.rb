require "test_helper"

class StripeEventMapperTest < ActiveSupport::TestCase
  test "maps active subscription to pro and addon seats" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)
    with_env("STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_abc", "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_abc") do
      payload = {
        "id" => "evt_mapper_1",
        "type" => "customer.subscription.updated",
        "data" => {
          "object" => {
            "id" => "sub_mapper_1",
            "customer" => "cus_mapper_1",
            "status" => "active",
            "current_period_end" => Time.current.to_i + 3600,
            "metadata" => { "operator_account_id" => operator.id },
            "items" => {
              "data" => [
                { "price" => { "id" => "price_pro_abc" }, "quantity" => 1 },
                { "price" => { "id" => "price_seat_abc" }, "quantity" => 5 }
              ]
            }
          }
        }
      }

      mapped = StripeEventMapper.new(payload).to_billing_event_payload
      assert_equal "stripe:evt_mapper_1", mapped[:id]
      assert_equal "subscription.updated", mapped[:type]
      assert_equal PlanEntitlement::PRO, mapped[:data][:plan]
      assert_equal 5, mapped[:data][:addon_seats]
      assert_equal StripePriceCatalog::MONTHLY, mapped[:data][:billing_interval]
      assert_equal "active", mapped[:data][:subscription_status]
    end
  end

  test "maps quantity-based pro seats when explicit seat addon prices are not configured" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)
    with_env(
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_qty",
      "STRIPE_PRO_PRICE_ID" => nil,
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => nil,
      "STRIPE_SEAT_ADDON_PRICE_ID" => nil
    ) do
      payload = {
        "id" => "evt_mapper_qty",
        "type" => "customer.subscription.updated",
        "data" => {
          "object" => {
            "id" => "sub_mapper_qty",
            "customer" => "cus_mapper_qty",
            "status" => "active",
            "metadata" => { "operator_account_id" => operator.id },
            "items" => {
              "data" => [
                { "price" => { "id" => "price_pro_qty" }, "quantity" => 4 }
              ]
            }
          }
        }
      }

      mapped = StripeEventMapper.new(payload).to_billing_event_payload
      assert_equal PlanEntitlement::PRO, mapped[:data][:plan]
      assert_equal 3, mapped[:data][:addon_seats]
    end
  end

  test "maps deleted subscription to cancellation event" do
    operator, = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 3)
    operator.update!(stripe_customer_id: "cus_mapper_2", stripe_subscription_id: "sub_mapper_2")

    payload = {
      "id" => "evt_mapper_2",
      "type" => "customer.subscription.deleted",
      "data" => {
        "object" => {
          "id" => "sub_mapper_2",
          "customer" => "cus_mapper_2",
          "status" => "canceled",
          "metadata" => {}
        }
      }
    }

    mapped = StripeEventMapper.new(payload).to_billing_event_payload
    assert_equal "subscription.canceled", mapped[:type]
    assert_equal operator.id, mapped[:data][:operator_account_id]
  end

  test "maps checkout session completion to pro subscription update" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)

    payload = {
      "id" => "evt_mapper_checkout",
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => "cs_test_123",
          "object" => "checkout.session",
          "mode" => "subscription",
          "customer" => "cus_checkout_1",
          "subscription" => "sub_checkout_1",
          "client_reference_id" => operator.id,
          "metadata" => { "operator_account_id" => operator.id, "addon_seats" => "0", "billing_interval" => "yearly" }
        }
      }
    }

    mapped = StripeEventMapper.new(payload).to_billing_event_payload
    assert_equal "subscription.updated", mapped[:type]
    assert_equal operator.id, mapped[:data][:operator_account_id]
    assert_equal "sub_checkout_1", mapped[:data][:stripe_subscription_id]
    assert_equal PlanEntitlement::PRO, mapped[:data][:plan]
    assert_equal StripePriceCatalog::MONTHLY, mapped[:data][:billing_interval]
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
