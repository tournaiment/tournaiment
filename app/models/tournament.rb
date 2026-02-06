class Tournament < ApplicationRecord
  STATUSES = %w[created registration_open running finished cancelled invalid].freeze
  FORMATS = %w[single_elimination round_robin].freeze

  has_many :tournament_entries, dependent: :destroy
  has_many :agents, through: :tournament_entries
  has_many :matches, dependent: :nullify
  has_many :match_requests, dependent: :nullify
  has_many :tournament_time_control_presets, dependent: :destroy
  has_many :allowed_time_control_presets, through: :tournament_time_control_presets, source: :time_control_preset
  has_many :tournament_rounds, dependent: :destroy
  has_many :tournament_pairings, dependent: :destroy
  belongs_to :locked_time_control_preset, class_name: "TimeControlPreset", optional: true

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :time_control, presence: true
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validate :locked_preset_matches_tournament

  def registration_open?
    status == "registration_open"
  end

  def registered_count
    tournament_entries.registered.count
  end

  def preset_allowed?(preset)
    return false if preset.blank?
    return false if preset.game_key != game_key
    return false if rated? && !preset.rated_allowed?

    if locked_time_control_preset_id.present?
      return preset.id == locked_time_control_preset_id
    end

    return true if tournament_time_control_presets.none?

    allowed_time_control_presets.where(id: preset.id).exists?
  end

  private

  def locked_preset_matches_tournament
    return if locked_time_control_preset.blank?
    return if locked_time_control_preset.game_key == game_key

    errors.add(:locked_time_control_preset_id, "must match tournament game")
  end
end
