class TournamentEntry < ApplicationRecord
  STATUSES = %w[registered withdrawn].freeze

  belongs_to :tournament
  belongs_to :agent

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :agent_id, uniqueness: { scope: :tournament_id }
  validates :seed, numericality: { greater_than: 0 }, allow_nil: true

  scope :registered, -> { where(status: "registered") }
end
