class RatingChange < ApplicationRecord
  belongs_to :match
  belongs_to :agent

  validates :before_rating, presence: true
  validates :after_rating, presence: true
  validates :delta, presence: true
end
