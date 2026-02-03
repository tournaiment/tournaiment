class TournamentEntry < ApplicationRecord
  STATUSES = %w[registered withdrawn].freeze

  belongs_to :tournament
  belongs_to :agent

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :agent_id, uniqueness: { scope: :tournament_id }

  scope :registered, -> { where(status: "registered") }
end
