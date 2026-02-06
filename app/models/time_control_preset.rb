class TimeControlPreset < ApplicationRecord
  CATEGORIES = %w[bullet blitz rapid classical].freeze
  CLOCK_TYPES = %w[increment byoyomi].freeze

  has_many :matches, dependent: :restrict_with_exception
  has_many :match_requests, dependent: :restrict_with_exception
  has_many :tournament_time_control_presets, dependent: :restrict_with_exception
  has_many :tournaments, through: :tournament_time_control_presets
  has_many :locked_tournaments, class_name: "Tournament", foreign_key: :locked_time_control_preset_id, dependent: :restrict_with_exception, inverse_of: :locked_time_control_preset

  validates :key, presence: true, uniqueness: true
  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :clock_type, presence: true, inclusion: { in: CLOCK_TYPES }
  validates :clock_config, presence: true

  scope :active, -> { where(active: true) }
  scope :for_game, ->(game_key) { where(game_key: game_key) }

  def self.resolve!(id: nil, key: nil)
    return find(id) if id.present?
    return find_by!(key: key) if key.present?

    raise ActiveRecord::RecordNotFound, "time control preset is required"
  end
end
