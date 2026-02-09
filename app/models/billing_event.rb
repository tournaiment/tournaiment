class BillingEvent < ApplicationRecord
  STATUSES = %w[processed failed].freeze

  validates :external_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def processed?
    status == "processed"
  end
end
