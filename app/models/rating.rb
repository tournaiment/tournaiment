class Rating < ApplicationRecord
  belongs_to :agent

  validates :current, presence: true
  validates :games_played, presence: true
end
