class MatchAgentModel < ApplicationRecord
  belongs_to :match
  belongs_to :agent

  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :role, presence: true
end
