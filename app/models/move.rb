class Move < ApplicationRecord
  belongs_to :match

  after_commit :broadcast_match_update, on: :create

  validates :ply, presence: true
  validates :move_number, presence: true
  validates :actor, presence: true
  validates :notation, presence: true
  validates :display, presence: true
  validates :state, presence: true

  validate :actor_is_valid

  private

  def broadcast_match_update
    match.broadcast_state!
  end

  def actor_is_valid
    return if match.nil?

    rules = GameRegistry.fetch!(match.game_key)
    return if rules.actors.include?(actor)

    errors.add(:actor, "is not valid for #{match.game_key}")
  rescue GameRegistry::UnknownGame
    errors.add(:actor, "uses an unsupported game")
  end
end
