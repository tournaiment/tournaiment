class MatchRequest < ApplicationRecord
  REQUEST_TYPES = %w[challenge ladder tournament].freeze
  STATUSES = %w[open matched cancelled expired].freeze

  belongs_to :requester_agent, class_name: "Agent"
  belongs_to :opponent_agent, class_name: "Agent", optional: true
  belongs_to :match, optional: true
  belongs_to :time_control_preset
  belongs_to :tournament, optional: true

  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :requester_agent_id, presence: true
  validates :time_control_preset_id, presence: true
  validate :opponent_rules
  validate :requester_is_not_opponent
  validate :preset_matches_game
  validate :rated_preset_allowed
  validate :tournament_rules
  validate :tournament_preset_allowed

  scope :open_requests, -> { where(status: "open") }

  def open?
    status == "open"
  end

  private

  def opponent_rules
    if request_type == "challenge" && opponent_agent_id.blank?
      errors.add(:opponent_agent_id, "is required for challenge requests")
    end
  end

  def requester_is_not_opponent
    return if requester_agent_id.blank? || opponent_agent_id.blank?
    return unless requester_agent_id == opponent_agent_id

    errors.add(:opponent_agent_id, "must be different from requester")
  end

  def preset_matches_game
    return if time_control_preset.blank? || game_key.blank?
    return if time_control_preset.game_key == game_key

    errors.add(:time_control_preset_id, "must match game key")
  end

  def rated_preset_allowed
    return unless rated
    return if time_control_preset.blank?
    return if time_control_preset.rated_allowed?

    errors.add(:time_control_preset_id, "is not approved for rated games")
  end

  def tournament_rules
    if request_type == "tournament" && tournament_id.blank?
      errors.add(:tournament_id, "is required for tournament requests")
    end

    return if tournament.blank?

    if tournament.game_key != game_key
      errors.add(:game_key, "must match tournament game")
    end

    if tournament.rated != rated
      errors.add(:rated, "must match tournament rated setting")
    end
  end

  def tournament_preset_allowed
    return if tournament.blank? || time_control_preset.blank?
    return if tournament.preset_allowed?(time_control_preset)

    errors.add(:time_control_preset_id, "is not allowed for this tournament")
  end
end
