class Tournament < ApplicationRecord
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  SHORT_ID_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".freeze
  SHORT_ID_PATTERN = /\A[0-9A-Za-z]+\z/
  SHORT_ID_MIN_LENGTH = 18
  SHORT_ID_MAX_LENGTH = 22
  LEGACY_SHORT_ID_PATTERN = /\A[0-9a-z]+\z/
  LEGACY_SHORT_ID_MIN_LENGTH = 20
  LEGACY_SHORT_ID_MAX_LENGTH = 26
  DEFAULT_TIME_ZONE = "UTC"
  TIME_ZONE_EDITABLE_STATUSES = %w[created registration_open].freeze
  URL_SLUG_WORD_LIMIT = 5
  URL_SLUG_CHAR_LIMIT = 48

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
  validates :time_zone, presence: true
  validates :monied, inclusion: { in: [ true, false ] }
  validate :time_zone_must_be_iana
  validate :time_zone_is_editable_for_status
  validate :locked_preset_matches_tournament

  def registration_open?
    status == "registration_open"
  end

  def to_param
    [ url_slug, short_id ].compact_blank.join("-")
  end

  def short_id
    self.class.encode_uuid(id)
  end

  def url_slug
    words = name.to_s.parameterize.split("-").first(URL_SLUG_WORD_LIMIT)
    words.join("-").first(URL_SLUG_CHAR_LIMIT)
  end

  def self.id_from_param!(value)
    parsed = id_from_param(value)
    raise ActiveRecord::RecordNotFound if parsed.blank?

    parsed
  end

  def self.id_from_param(value)
    raw = value.to_s
    return raw if UUID_PATTERN.match?(raw)

    token = raw.split("-").last
    return token if UUID_PATTERN.match?(token)
    return if token.blank?

    decode_short_id(token) || decode_legacy_short_id(token)
  end

  def self.encode_uuid(uuid)
    number = uuid.to_s.delete("-").to_i(16)
    encode_base62(number)
  end

  def self.decode_short_id(token)
    return if token.length < SHORT_ID_MIN_LENGTH || token.length > SHORT_ID_MAX_LENGTH
    return unless SHORT_ID_PATTERN.match?(token)

    number = decode_base62(token)
    return if number.nil?

    uuid_from_hex(number.to_s(16))
  end

  def self.decode_legacy_short_id(token)
    return if token.length < LEGACY_SHORT_ID_MIN_LENGTH || token.length > LEGACY_SHORT_ID_MAX_LENGTH
    return unless LEGACY_SHORT_ID_PATTERN.match?(token)

    uuid_from_hex(Integer(token, 36).to_s(16))
  rescue ArgumentError
    nil
  end

  def self.encode_base62(number)
    return SHORT_ID_ALPHABET[0] if number.zero?

    encoded = +""
    base = SHORT_ID_ALPHABET.length
    value = number
    while value.positive?
      value, remainder = value.divmod(base)
      encoded << SHORT_ID_ALPHABET[remainder]
    end
    encoded.reverse
  end

  def self.decode_base62(token)
    base = SHORT_ID_ALPHABET.length
    token.each_char.reduce(0) do |acc, char|
      index = SHORT_ID_ALPHABET.index(char)
      return nil if index.nil?

      (acc * base) + index
    end
  end

  def self.uuid_from_hex(hex)
    return if hex.length > 32

    padded = hex.rjust(32, "0")
    "#{padded[0, 8]}-#{padded[8, 4]}-#{padded[12, 4]}-#{padded[16, 4]}-#{padded[20, 12]}"
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

  def time_zone_must_be_iana
    return if time_zone.blank?

    TZInfo::Timezone.get(time_zone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:time_zone, "must be a valid IANA timezone identifier")
  end

  def time_zone_is_editable_for_status
    return unless persisted?
    return unless will_save_change_to_time_zone?
    return if TIME_ZONE_EDITABLE_STATUSES.include?(status)

    errors.add(:time_zone, "cannot be changed after tournament starts")
  end

  def locked_preset_matches_tournament
    return if locked_time_control_preset.blank?
    return if locked_time_control_preset.game_key == game_key

    errors.add(:locked_time_control_preset_id, "must match tournament game")
  end
end
