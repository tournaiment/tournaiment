require "test_helper"

class BillingWebhooksFlowTest < ActionDispatch::IntegrationTest
  test "subscription cancellation downgrades to free and enforces one active seat with idempotency" do
    operator, = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2)
    first, = create_agent_for_operator(operator_account: operator, name: "BW_A1")
    second, = create_agent_for_operator(operator_account: operator, name: "BW_A2")
    third, = create_agent_for_operator(operator_account: operator, name: "BW_A3")

    payload = {
      id: "evt_cancel_#{SecureRandom.hex(6)}",
      type: "subscription.canceled",
      data: {
        operator_account_id: operator.id,
        subscription_status: "canceled"
      }
    }

    post "/billing/webhooks", params: payload, as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal false, body["duplicate"]

    entitlement = operator.reload.entitlement
    assert_equal PlanEntitlement::FREE, entitlement.plan
    assert_equal 0, entitlement.addon_seats
    assert_equal "active", first.reload.status
    assert_equal "suspended_no_seat", second.reload.status
    assert_equal "suspended_no_seat", third.reload.status

    post "/billing/webhooks", params: payload, as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal true, body["duplicate"]
    assert_equal 1, BillingEvent.where(external_event_id: payload[:id]).count
  end

  test "past_due webhook keeps pro during grace then downgrades after expiry signal" do
    operator, = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2, billing_interval: StripePriceCatalog::MONTHLY)
    first, = create_agent_for_operator(operator_account: operator, name: "BW_PD_A1")
    second, = create_agent_for_operator(operator_account: operator, name: "BW_PD_A2")
    third, = create_agent_for_operator(operator_account: operator, name: "BW_PD_A3")

    grace_payload = {
      id: "evt_past_due_grace_#{SecureRandom.hex(6)}",
      type: "subscription.updated",
      data: {
        operator_account_id: operator.id,
        plan: PlanEntitlement::PRO,
        billing_interval: StripePriceCatalog::MONTHLY,
        subscription_status: "past_due",
        addon_seats: 2
      }
    }

    with_env("BILLING_PAST_DUE_GRACE_DAYS" => "3") do
      post "/billing/webhooks", params: grace_payload, as: :json
    end
    assert_response :ok

    entitlement = operator.reload.entitlement
    assert_equal PlanEntitlement::PRO, entitlement.plan
    assert_equal StripePriceCatalog::MONTHLY, entitlement.billing_interval
    assert_equal "past_due", entitlement.subscription_status
    assert entitlement.payment_grace_ends_at.present?
    assert_equal "active", first.reload.status
    assert_equal "active", second.reload.status
    assert_equal "active", third.reload.status

    expired_payload = {
      id: "evt_past_due_expired_#{SecureRandom.hex(6)}",
      type: "subscription.updated",
      data: {
        operator_account_id: operator.id,
        plan: PlanEntitlement::PRO,
        subscription_status: "past_due",
        payment_grace_ends_at: 1.hour.ago.iso8601,
        addon_seats: 2
      }
    }

    post "/billing/webhooks", params: expired_payload, as: :json
    assert_response :ok

    entitlement = operator.reload.entitlement
    assert_equal PlanEntitlement::FREE, entitlement.plan
    assert_nil entitlement.billing_interval
    assert_nil entitlement.payment_grace_ends_at
    assert_equal "active", first.reload.status
    assert_equal "suspended_no_seat", second.reload.status
    assert_equal "suspended_no_seat", third.reload.status
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
