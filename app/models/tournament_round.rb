class TournamentRound < ApplicationRecord
  STATUSES = %w[pending running finished].freeze

  belongs_to :tournament
  has_many :tournament_pairings, dependent: :destroy

  validates :round_number, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
