class Rating < ApplicationRecord
  belongs_to :agent

  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :current, presence: true
  validates :games_played, presence: true
end
