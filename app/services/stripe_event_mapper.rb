require "time"

class StripeEventMapper
  SUPPORTED_EVENT_TYPES = %w[
    checkout.session.completed
    customer.subscription.created
    customer.subscription.updated
    customer.subscription.deleted
  ].freeze

  ACTIVE_SUBSCRIPTION_STATUSES = %w[active trialing past_due].freeze

  def initialize(event_payload)
    @event_payload = event_payload.deep_stringify_keys
  end

  def to_billing_event_payload
    return nil unless SUPPORTED_EVENT_TYPES.include?(event_type)

    return map_checkout_session_completed if event_type == "checkout.session.completed"

    operator = resolve_operator_account!
    subscription = event_object

    operator.sync_stripe_references!(
      customer_id: stripe_customer_id(subscription),
      subscription_id: stripe_subscription_id(subscription)
    )

    if event_type == "customer.subscription.deleted"
      return {
        id: "stripe:#{event_id}",
        type: "subscription.canceled",
        data: base_data(operator)
      }
    end

    {
      id: "stripe:#{event_id}",
      type: "subscription.updated",
      data: base_data(operator).merge(
        plan: derived_plan(subscription),
        addon_seats: addon_seats_for(subscription),
        billing_interval: billing_interval_for(subscription),
        subscription_status: subscription["status"].to_s.presence || "inactive",
        current_period_ends_at: period_end_iso8601(subscription)
      )
    }
  end

  private

  def event_id
    @event_payload.fetch("id")
  end

  def event_type
    @event_payload.fetch("type")
  end

  def event_object
    object = @event_payload.dig("data", "object")
    return object if object.is_a?(Hash)

    raise ArgumentError, "Stripe event payload missing data.object"
  end

  def base_data(operator)
    {
      operator_account_id: operator.id,
      stripe_customer_id: stripe_customer_id(event_object),
      stripe_subscription_id: stripe_subscription_id(event_object)
    }
  end

  def map_checkout_session_completed
    session = event_object
    return nil unless session["mode"] == "subscription"

    operator = resolve_operator_account_for_checkout!(session)
    operator.sync_stripe_references!(
      customer_id: stripe_customer_id(session),
      subscription_id: stripe_subscription_id(session)
    )

    addon_seats = session.dig("metadata", "addon_seats").to_i
    billing_interval = StripePriceCatalog.normalize_interval_strict(session.dig("metadata", "billing_interval")) || StripePriceCatalog::MONTHLY
    {
      id: "stripe:#{event_id}",
      type: "subscription.updated",
      data: {
        operator_account_id: operator.id,
        stripe_customer_id: stripe_customer_id(session),
        stripe_subscription_id: stripe_subscription_id(session),
        plan: PlanEntitlement::PRO,
        addon_seats: addon_seats,
        billing_interval: billing_interval,
        subscription_status: "active"
      }
    }
  end

  def resolve_operator_account!
    metadata_operator_id = event_object.dig("metadata", "operator_account_id").to_s.presence
    return OperatorAccount.find(metadata_operator_id) if metadata_operator_id.present?

    customer_id = stripe_customer_id(event_object)
    if customer_id.present?
      account = OperatorAccount.find_by(stripe_customer_id: customer_id)
      return account if account
    end

    subscription_id = stripe_subscription_id(event_object)
    if subscription_id.present?
      account = OperatorAccount.find_by(stripe_subscription_id: subscription_id)
      return account if account
    end

    raise ActiveRecord::RecordNotFound, "Unable to map Stripe subscription to operator account"
  end

  def resolve_operator_account_for_checkout!(session)
    operator_id = session.dig("metadata", "operator_account_id").to_s.presence || session["client_reference_id"].to_s.presence
    return OperatorAccount.find(operator_id) if operator_id.present?

    customer_id = stripe_customer_id(session)
    if customer_id.present?
      account = OperatorAccount.find_by(stripe_customer_id: customer_id)
      return account if account
    end

    raise ActiveRecord::RecordNotFound, "Unable to map Stripe checkout session to operator account"
  end

  def derived_plan(subscription)
    return PlanEntitlement::FREE unless ACTIVE_SUBSCRIPTION_STATUSES.include?(subscription["status"].to_s)

    pro_prices = StripePriceCatalog.pro_price_ids
    return PlanEntitlement::PRO if pro_prices.empty?

    prices = subscription_item_prices(subscription)
    prices.any? { |price_id| pro_prices.include?(price_id) } ? PlanEntitlement::PRO : PlanEntitlement::FREE
  end

  def addon_seats_for(subscription)
    return 0 unless derived_plan(subscription) == PlanEntitlement::PRO

    items = subscription_items(subscription)
    addon_prices = StripePriceCatalog.seat_addon_price_ids

    if addon_prices.any?
      return items.select { |item| addon_prices.include?(item.dig("price", "id")) }.sum { |item| item.fetch("quantity", 0).to_i }
    end

    # Fallback for quantity-based seat modeling where the base pro item quantity represents total seats.
    pro_item = items.find { |item| StripePriceCatalog.pro_price_ids.include?(item.dig("price", "id")) }
    return 0 unless pro_item

    [ pro_item.fetch("quantity", 0).to_i - EntitlementService::INCLUDED_SEATS, 0 ].max
  end

  def subscription_item_prices(subscription)
    subscription_items(subscription).map { |item| item.dig("price", "id") }.compact
  end

  def billing_interval_for(subscription)
    return nil unless derived_plan(subscription) == PlanEntitlement::PRO

    metadata_interval = StripePriceCatalog.normalize_interval_strict(subscription.dig("metadata", "billing_interval"))
    return metadata_interval if metadata_interval.present?

    StripePriceCatalog::MONTHLY
  end

  def subscription_items(subscription)
    items = subscription.dig("items", "data")
    return [] unless items.is_a?(Array)

    items
  end

  def period_end_iso8601(subscription)
    period_end = subscription["current_period_end"]
    return nil if period_end.blank?

    Time.at(period_end.to_i).utc.iso8601
  end

  def stripe_customer_id(payload)
    payload["customer"].to_s.presence
  end

  def stripe_subscription_id(payload)
    if payload["object"] == "checkout.session"
      return payload["subscription"].to_s.presence
    end

    payload["subscription"].to_s.presence || payload["id"].to_s.presence
  end
end
