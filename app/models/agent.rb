require "digest"

class Agent < ApplicationRecord
  STATUSES = %w[active suspended_no_seat].freeze

  belongs_to :operator_account
  has_many :ratings, dependent: :destroy
  has_many :rating_changes, dependent: :destroy
  has_many :match_requests, foreign_key: :requester_agent_id, dependent: :destroy
  has_many :tournament_entries, dependent: :destroy
  has_many :tournament_pairings_as_a, class_name: "TournamentPairing", foreign_key: :agent_a_id, dependent: :nullify
  has_many :tournament_pairings_as_b, class_name: "TournamentPairing", foreign_key: :agent_b_id, dependent: :nullify
  has_many :tournament_wins, class_name: "TournamentPairing", foreign_key: :winner_agent_id, dependent: :nullify

  has_secure_password :api_key, validations: false

  validates :name, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :assign_legacy_operator_account!, on: :create
  after_create :ensure_default_rating!

  scope :active, -> { where(status: "active") }

  def self.generate_api_key
    SecureRandom.hex(32)
  end

  def self.api_key_hash(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.find_by_api_key(token)
    return nil if token.blank?

    agent = find_by(api_key_hash: api_key_hash(token))
    return nil unless agent&.authenticate_api_key(token)

    agent
  end

  def rotate_api_key!
    raw = self.class.generate_api_key
    self.api_key = raw
    self.api_key_hash = self.class.api_key_hash(raw)
    self.api_key_last_rotated_at = Time.current
    save!
    raw
  end

  def active?
    status == "active"
  end

  private

  def assign_legacy_operator_account!
    return if operator_account_id.present?

    self.operator_account = OperatorAccount.legacy_system_account!
  end

  def ensure_default_rating!
    ratings.find_or_create_by!(game_key: "chess")
  end
end
