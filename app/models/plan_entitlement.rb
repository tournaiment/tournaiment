class PlanEntitlement < ApplicationRecord
  FREE = "free"
  PRO = "pro"
  PLANS = [ FREE, PRO ].freeze
  BILLING_INTERVALS = [ StripePriceCatalog::MONTHLY ].freeze

  belongs_to :operator_account

  validates :plan, presence: true, inclusion: { in: PLANS }
  validates :addon_seats, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :billing_interval, inclusion: { in: BILLING_INTERVALS }, allow_nil: true
  validate :addon_seats_allowed_for_plan
  validate :billing_interval_allowed_for_plan

  def free?
    plan == FREE
  end

  def pro?
    plan == PRO
  end

  private

  def addon_seats_allowed_for_plan
    return if pro?
    return if addon_seats.to_i.zero?

    errors.add(:addon_seats, "is only available on pro")
  end

  def billing_interval_allowed_for_plan
    return if pro?
    return if billing_interval.blank?

    errors.add(:billing_interval, "is only available on pro")
  end
end
