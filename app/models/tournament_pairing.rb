class TournamentPairing < ApplicationRecord
  STATUSES = %w[pending running finished].freeze

  belongs_to :tournament
  belongs_to :tournament_round
  belongs_to :agent_a, class_name: "Agent"
  belongs_to :agent_b, class_name: "Agent", optional: true
  belongs_to :winner_agent, class_name: "Agent", optional: true

  has_one :match, dependent: :nullify

  validates :slot, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def ready?
    status == "pending" && !bye?
  end

  def finished?
    status == "finished"
  end
end
