class BillingWebhookProcessor
  ACTIVE_SUBSCRIPTION_STATUSES = %w[active trialing].freeze
  GRACE_SUBSCRIPTION_STATUSES = %w[past_due].freeze
  TERMINAL_SUBSCRIPTION_STATUSES = %w[canceled unpaid incomplete incomplete_expired].freeze
  DEFAULT_PAST_DUE_GRACE_DAYS = 7

  SUPPORTED_EVENT_TYPES = %w[
    subscription.activated
    subscription.updated
    subscription.canceled
    subscription.expired
    seat_addon.updated
  ].freeze

  def initialize(payload)
    @payload = payload.to_h.deep_stringify_keys
  end

  def call
    event_id = @payload["id"].to_s
    event_type = @payload["type"].to_s

    raise ArgumentError, "Billing event id is required" if event_id.blank?
    raise ArgumentError, "Billing event type is required" if event_type.blank?

    BillingEvent.transaction do
      billing_event = BillingEvent.lock.find_by(external_event_id: event_id)
      return :duplicate if billing_event&.processed?

      billing_event ||= BillingEvent.new(external_event_id: event_id)
      billing_event.event_type = event_type
      billing_event.payload = @payload

      apply_event!(event_type)

      billing_event.status = "processed"
      billing_event.processed_at = Time.current
      billing_event.error_message = nil
      billing_event.save!
    end

    :processed
  rescue StandardError => e
    mark_failure!(event_id: event_id, event_type: event_type, error: e)
    raise
  end

  private

  def apply_event!(event_type)
    unless SUPPORTED_EVENT_TYPES.include?(event_type)
      raise ArgumentError, "Unsupported billing event type: #{event_type}"
    end

    operator_account = resolve_operator_account!
    entitlement = operator_account.entitlement
    data = event_data

    case event_type
    when "subscription.activated"
      apply_subscription_activation!(entitlement, data)
    when "subscription.updated"
      apply_subscription_update!(entitlement, data)
    when "subscription.canceled", "subscription.expired"
      apply_subscription_cancellation!(entitlement, data)
    when "seat_addon.updated"
      apply_seat_addon_update!(entitlement, data)
    end

    active_ids = SeatAllocationService.new(operator_account).call
    AuditLog.log!(
      actor: operator_account,
      action: "billing.webhook_processed",
      auditable: entitlement,
      metadata: {
        event_id: @payload["id"],
        event_type: event_type,
        plan: entitlement.plan,
        billing_interval: entitlement.billing_interval,
        addon_seats: entitlement.addon_seats,
        subscription_status: entitlement.subscription_status,
        payment_grace_ends_at: entitlement.payment_grace_ends_at,
        active_agent_ids: active_ids
      }
    )
  end

  def apply_subscription_activation!(entitlement, data)
    apply_subscription_update!(entitlement, data.merge("plan" => PlanEntitlement::PRO))
  end

  def apply_subscription_update!(entitlement, data)
    status = subscription_status_for(data, default: entitlement.subscription_status.presence || "inactive")
    plan = data["plan"].presence || entitlement.plan

    if plan == PlanEntitlement::FREE || TERMINAL_SUBSCRIPTION_STATUSES.include?(status)
      apply_subscription_cancellation!(entitlement, data.merge("subscription_status" => status))
      return
    end

    if GRACE_SUBSCRIPTION_STATUSES.include?(status)
      apply_subscription_past_due!(entitlement, data, status:)
      return
    end

    unless ACTIVE_SUBSCRIPTION_STATUSES.include?(status)
      apply_subscription_cancellation!(entitlement, data.merge("subscription_status" => status))
      return
    end

    interval = billing_interval_from(data, default: entitlement.billing_interval)

    entitlement.update!(
      plan: PlanEntitlement::PRO,
      billing_interval: interval,
      subscription_status: status,
      current_period_ends_at: parse_time(data["current_period_ends_at"]) || entitlement.current_period_ends_at,
      payment_grace_ends_at: nil,
      addon_seats: integer_value(data["addon_seats"], default: entitlement.addon_seats)
    )
  end

  def apply_subscription_cancellation!(entitlement, data)
    entitlement.update!(
      plan: PlanEntitlement::FREE,
      billing_interval: nil,
      addon_seats: 0,
      subscription_status: data["subscription_status"].presence || "inactive",
      current_period_ends_at: parse_time(data["current_period_ends_at"]) || entitlement.current_period_ends_at,
      payment_grace_ends_at: nil
    )
  end

  def apply_seat_addon_update!(entitlement, data)
    unless entitlement.pro?
      raise ArgumentError, "Seat add-ons require pro plan"
    end

    entitlement.update!(
      addon_seats: integer_value(data["addon_seats"]),
      subscription_status: data["subscription_status"].presence || entitlement.subscription_status,
      current_period_ends_at: parse_time(data["current_period_ends_at"]) || entitlement.current_period_ends_at,
      billing_interval: billing_interval_from(data, default: entitlement.billing_interval)
    )
  end

  def apply_subscription_past_due!(entitlement, data, status:)
    grace_ends_at = parse_time(data["payment_grace_ends_at"]) || entitlement.payment_grace_ends_at || (Time.current + grace_period_days.days)
    if grace_ends_at <= Time.current
      apply_subscription_cancellation!(
        entitlement,
        data.merge(
          "subscription_status" => "past_due_grace_expired",
          "current_period_ends_at" => data["current_period_ends_at"]
        )
      )
      return
    end

    entitlement.update!(
      plan: PlanEntitlement::PRO,
      billing_interval: billing_interval_from(data, default: entitlement.billing_interval),
      subscription_status: status,
      current_period_ends_at: parse_time(data["current_period_ends_at"]) || entitlement.current_period_ends_at,
      payment_grace_ends_at: grace_ends_at,
      addon_seats: integer_value(data["addon_seats"], default: entitlement.addon_seats)
    )
  end

  def resolve_operator_account!
    data = event_data
    operator_id = data["operator_account_id"].to_s.presence
    operator_email = data["operator_email"].to_s.strip.downcase.presence

    if operator_id.present?
      return OperatorAccount.find(operator_id)
    end
    if operator_email.present?
      return OperatorAccount.find_by!(email: operator_email)
    end

    raise ArgumentError, "Billing event must include operator_account_id or operator_email"
  end

  def event_data
    @payload["data"].is_a?(Hash) ? @payload["data"] : {}
  end

  def integer_value(value, default: nil)
    return default if value.nil? && !default.nil?

    number = Integer(value)
    raise ArgumentError, "Seat add-ons cannot be negative" if number.negative?

    number
  rescue ArgumentError, TypeError
    raise ArgumentError, "Invalid integer value: #{value.inspect}"
  end

  def billing_interval_from(data, default:)
    raw = data["billing_interval"].to_s.strip
    if raw.blank?
      normalized_default = StripePriceCatalog.normalize_interval_strict(default)
      return normalized_default if normalized_default.present?

      return StripePriceCatalog::MONTHLY
    end

    interval = StripePriceCatalog.normalize_interval(raw)
    return interval if interval == StripePriceCatalog::MONTHLY

    raise ArgumentError, "Only monthly billing is supported."
  end

  def subscription_status_for(data, default:)
    status = data["subscription_status"].to_s.strip
    return default if status.blank?

    status
  end

  def grace_period_days
    value = ENV.fetch("BILLING_PAST_DUE_GRACE_DAYS", DEFAULT_PAST_DUE_GRACE_DAYS.to_s)
    number = Integer(value)
    raise ArgumentError, "BILLING_PAST_DUE_GRACE_DAYS must be >= 0" if number.negative?

    number
  rescue ArgumentError, TypeError
    raise ArgumentError, "Invalid BILLING_PAST_DUE_GRACE_DAYS: #{value.inspect}"
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    raise ArgumentError, "Invalid timestamp: #{value.inspect}"
  end

  def mark_failure!(event_id:, event_type:, error:)
    return if event_id.blank?

    event = BillingEvent.find_or_initialize_by(external_event_id: event_id)
    event.event_type = event_type.presence || "unknown"
    event.payload = @payload
    event.status = "failed"
    event.error_message = error.message.to_s.truncate(1000)
    event.processed_at = nil
    event.save!
  rescue StandardError
    # Swallow secondary persistence errors to preserve the original failure.
    nil
  end
end
