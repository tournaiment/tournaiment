class Admin < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end
end
