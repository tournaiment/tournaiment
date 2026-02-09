require "digest"

class OperatorAccount < ApplicationRecord
  LEGACY_SYSTEM_EMAIL = "legacy-system@tournaiment.local"
  STATUSES = %w[active suspended].freeze

  has_secure_password
  has_secure_password :api_token, validations: false

  has_many :agents, dependent: :restrict_with_error
  has_one :plan_entitlement, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :stripe_customer_id, uniqueness: true, allow_nil: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  before_validation :normalize_email
  after_create :ensure_plan_entitlement!

  def self.generate_api_token
    SecureRandom.hex(32)
  end

  def self.api_token_hash(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.find_by_api_token(token)
    return nil if token.blank?

    account = find_by(api_token_hash: api_token_hash(token))
    return nil unless account&.authenticate_api_token(token)

    account
  end

  def self.legacy_system_account!
    account = find_or_create_by!(email: LEGACY_SYSTEM_EMAIL) do |record|
      raw_token = generate_api_token
      record.password = SecureRandom.hex(32)
      record.api_token = raw_token
      record.api_token_hash = api_token_hash(raw_token)
      record.api_token_last_rotated_at = Time.current
      record.email_verified_at = Time.current
      record.status = "active"
    end

    entitlement = account.entitlement
    return account if entitlement.pro? && entitlement.addon_seats >= 10_000 && entitlement.subscription_status == "legacy_grandfathered"

    entitlement.update!(plan: PlanEntitlement::PRO, addon_seats: 10_000, subscription_status: "legacy_grandfathered")
    account
  end

  def rotate_api_token!
    raw = self.class.generate_api_token
    self.api_token = raw
    self.api_token_hash = self.class.api_token_hash(raw)
    self.api_token_last_rotated_at = Time.current
    save!
    raw
  end

  def entitlement
    plan_entitlement || build_plan_entitlement.tap(&:save!)
  end

  def active?
    status == "active"
  end

  def sync_stripe_references!(customer_id: nil, subscription_id: nil)
    attrs = {}
    attrs[:stripe_customer_id] = customer_id if customer_id.present?
    attrs[:stripe_subscription_id] = subscription_id if subscription_id.present?
    return if attrs.empty?

    update!(attrs)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def ensure_plan_entitlement!
    create_plan_entitlement!(plan: PlanEntitlement::FREE, addon_seats: 0, subscription_status: "inactive") unless plan_entitlement
  end
end
