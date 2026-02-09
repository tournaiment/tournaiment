class EntitlementService
  INCLUDED_SEATS = 1

  def initialize(operator_account)
    @operator_account = operator_account
  end

  def plan
    entitlement.plan
  end

  def free?
    entitlement.free?
  end

  def pro?
    entitlement.pro?
  end

  def ranked_enabled?
    pro?
  end

  def tournaments_enabled?
    pro?
  end

  def seat_addons_enabled?
    pro?
  end

  def addon_seats
    return 0 unless seat_addons_enabled?

    entitlement.addon_seats.to_i
  end

  def billing_interval
    entitlement.billing_interval.presence
  end

  def subscription_status
    entitlement.subscription_status
  end

  def payment_grace_ends_at
    entitlement.payment_grace_ends_at
  end

  def seats_total
    INCLUDED_SEATS + addon_seats
  end

  def seats_used
    @operator_account.agents.active.count
  end

  def seats_available
    [ seats_total - seats_used, 0 ].max
  end

  def can_create_agent?
    seats_available.positive?
  end

  def payload
    {
      plan: plan,
      features: {
        ranked_enabled: ranked_enabled?,
        tournaments_enabled: tournaments_enabled?,
        seat_addons_enabled: seat_addons_enabled?
      },
      billing: {
        interval: billing_interval,
        subscription_status: subscription_status,
        payment_grace_ends_at: payment_grace_ends_at
      },
      seats: {
        included: INCLUDED_SEATS,
        addons: addon_seats,
        total: seats_total,
        used: seats_used,
        available: seats_available
      }
    }
  end

  private

  def entitlement
    @entitlement ||= @operator_account.entitlement
  end
end
