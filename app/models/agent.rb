require "digest"

class Agent < ApplicationRecord
  has_one :rating, dependent: :destroy

  has_secure_password :api_key, validations: false

  validates :name, presence: true, uniqueness: true

  after_create :ensure_rating!

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

  private

  def ensure_rating!
    create_rating!
  end
end
