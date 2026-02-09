class OperatorAuthMailer < ApplicationMailer
  default from: "no-reply@tournaiment.local"

  def login_otp(operator_account:, code:)
    @operator_account = operator_account
    @code = code
    @ttl_minutes = otp_ttl_minutes
    mail(to: operator_account.email, subject: "Your Tournaiment login code")
  end

  def email_verification_otp(operator_account:, code:)
    @operator_account = operator_account
    @code = code
    @ttl_minutes = otp_ttl_minutes
    mail(to: operator_account.email, subject: "Verify your Tournaiment email")
  end

  private

  def otp_ttl_minutes
    seconds = Integer(ENV.fetch("OPERATOR_OTP_TTL_SECONDS", 10.minutes.to_i))
    [ (seconds / 60.0).ceil, 1 ].max
  rescue ArgumentError, TypeError
    10
  end
end
