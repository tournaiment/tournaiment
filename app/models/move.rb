class Move < ApplicationRecord
  COLORS = %w[white black].freeze

  belongs_to :match

  validates :ply, presence: true
  validates :move_number, presence: true
  validates :color, presence: true, inclusion: { in: COLORS }
  validates :uci, presence: true
  validates :san, presence: true
  validates :fen, presence: true
end
