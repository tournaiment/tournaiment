class OperatorOneTimePasscode < ApplicationRecord
  PURPOSE_LOGIN = "login"
  PURPOSE_EMAIL_VERIFICATION = "email_verification"
  PURPOSES = [ PURPOSE_LOGIN, PURPOSE_EMAIL_VERIFICATION ].freeze

  belongs_to :operator_account

  validates :purpose, presence: true, inclusion: { in: PURPOSES }
  validates :code_digest, presence: true
  validates :expires_at, presence: true
  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :unconsumed, -> { where(consumed_at: nil) }
  scope :active, -> { unconsumed.where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end
end
