require "test_helper"

class BillingWebhookProcessorTest < ActiveSupport::TestCase
  test "subscription activation upgrades to pro and reactivates suspended agents by creation order" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)
    first, = create_agent_for_operator(operator_account: operator, name: "BWP_A1")
    second, = create_agent_for_operator(operator_account: operator, name: "BWP_A2")
    third, = create_agent_for_operator(operator_account: operator, name: "BWP_A3")

    # Enforce free allocation baseline: only first agent active.
    SeatAllocationService.new(operator).call
    assert_equal "active", first.reload.status
    assert_equal "suspended_no_seat", second.reload.status
    assert_equal "suspended_no_seat", third.reload.status

    payload = {
      id: "evt_activate_#{SecureRandom.hex(6)}",
      type: "subscription.activated",
      data: {
        operator_account_id: operator.id,
        addon_seats: 2,
        subscription_status: "active"
      }
    }

    result = BillingWebhookProcessor.new(payload).call
    assert_equal :processed, result

    entitlement = operator.reload.entitlement
    assert_equal PlanEntitlement::PRO, entitlement.plan
    assert_equal 2, entitlement.addon_seats
    assert_equal "active", first.reload.status
    assert_equal "active", second.reload.status
    assert_equal "active", third.reload.status
  end

  test "seat_addon update fails when account is not pro and records failed event" do
    operator, = create_operator_account(plan: PlanEntitlement::FREE)
    payload = {
      id: "evt_addon_fail_#{SecureRandom.hex(6)}",
      type: "seat_addon.updated",
      data: {
        operator_account_id: operator.id,
        addon_seats: 3
      }
    }

    assert_raises(ArgumentError) { BillingWebhookProcessor.new(payload).call }

    event = BillingEvent.find_by!(external_event_id: payload[:id])
    assert_equal "failed", event.status
    assert_match("Seat add-ons require pro plan", event.error_message)
  end

  test "past_due update preserves pro during grace and records grace end timestamp" do
    operator, = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2, billing_interval: StripePriceCatalog::MONTHLY)
    payload = {
      id: "evt_past_due_grace_#{SecureRandom.hex(6)}",
      type: "subscription.updated",
      data: {
        operator_account_id: operator.id,
        plan: PlanEntitlement::PRO,
        subscription_status: "past_due",
        billing_interval: StripePriceCatalog::MONTHLY,
        addon_seats: 2
      }
    }

    with_env("BILLING_PAST_DUE_GRACE_DAYS" => "5") do
      result = BillingWebhookProcessor.new(payload).call
      assert_equal :processed, result
    end

    entitlement = operator.reload.entitlement
    assert_equal PlanEntitlement::PRO, entitlement.plan
    assert_equal "past_due", entitlement.subscription_status
    assert_equal StripePriceCatalog::MONTHLY, entitlement.billing_interval
    assert entitlement.payment_grace_ends_at.present?
    assert_in_delta 5.days.from_now.to_f, entitlement.payment_grace_ends_at.to_f, 5
  end

  test "past_due update downgrades when grace is expired" do
    operator, = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2)
    payload = {
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

    result = BillingWebhookProcessor.new(payload).call
    assert_equal :processed, result

    entitlement = operator.reload.entitlement
    assert_equal PlanEntitlement::FREE, entitlement.plan
    assert_equal 0, entitlement.addon_seats
    assert_equal "past_due_grace_expired", entitlement.subscription_status
    assert_nil entitlement.billing_interval
    assert_nil entitlement.payment_grace_ends_at
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
