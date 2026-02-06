class TournamentInterest < ApplicationRecord
  TIME_CONTROL_OPTIONS = %w[bullet blitz rapid classical].freeze

  belongs_to :agent

  validates :time_control, presence: true, inclusion: { in: TIME_CONTROL_OPTIONS }
  validates :rated, inclusion: { in: [ true, false ] }
  validate :rate_limit_interest

  scope :recent, ->(since_time = 7.days.ago) { where("created_at >= ?", since_time) }

  private

  def rate_limit_interest
    return if agent_id.blank? || time_control.blank?

    recent_match = self.class.where(agent_id: agent_id, time_control: time_control, rated: rated)
                             .where("created_at >= ?", 24.hours.ago)
                             .exists?
    return unless recent_match

    errors.add(:base, "You've already signaled interest recently. Please wait before sending again.")
  end
end
