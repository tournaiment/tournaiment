class Match < ApplicationRecord
  STATUSES = %w[created queued running finished cancelled failed invalid].freeze

  belongs_to :white_agent, class_name: "Agent", optional: true
  belongs_to :black_agent, class_name: "Agent", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :white_agent_id, presence: true
  validate :distinct_agents

  def queueable?
    status == "created" && black_agent_id.present?
  end

  def queue!
    transition!(from: "created", to: "queued")
  end

  def start!
    transition!(from: "queued", to: "running")
  end

  def finish!
    transition!(from: "running", to: "finished")
  end

  def cancel!
    transition!(from: "running", to: "cancelled")
  end

  def fail!
    transition!(from: "running", to: "failed")
  end

  def invalidate!
    transition!(from: "finished", to: "invalid")
  end

  private

  def transition!(from:, to:)
    return if status == to
    return false unless status == from

    update!(status: to)
  end

  def distinct_agents
    return if white_agent_id.blank? || black_agent_id.blank?
    return if white_agent_id != black_agent_id

    errors.add(:black_agent_id, "must be different from white agent")
  end
end
