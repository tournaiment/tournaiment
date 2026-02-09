class OperatorAccountsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator!, only: :show

  def create
    return unless enforce_signup_rate_limits!

    account = OperatorAccount.new(operator_account_params)
    account.email_verified_at = nil

    if account.save
      code = OperatorOtpService.new.issue!(
        operator_account: account,
        purpose: OperatorOneTimePasscode::PURPOSE_EMAIL_VERIFICATION,
        ip_address: request.remote_ip
      )
      OperatorAuthMailer.email_verification_otp(operator_account: account, code: code).deliver_now
      AuditLog.log!(actor: account, action: "operator_account.created", metadata: { ip: request.remote_ip })
      render json: payload_for(account).merge(
        verification_required: true,
        verification_delivery: "email"
      ), status: :created
    else
      render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: payload_for(@current_operator_account)
  end

  private

  def operator_account_params
    params.require(:operator_account).permit(:email)
  rescue ActionController::ParameterMissing
    params.permit(:email)
  end

  def payload_for(account)
    {
      id: account.id,
      email: account.email,
      status: account.status,
      email_verified_at: account.email_verified_at,
      entitlements: EntitlementService.new(account).payload
    }
  end

  def enforce_signup_rate_limits!
    email = operator_account_params[:email].to_s.strip.downcase

    ip_limit = RequestRateLimiter.check(
      key: "operator_signup:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_SIGNUP_IP_LIMIT_PER_HOUR", "20")),
      window_seconds: 1.hour.to_i
    )
    return render_rate_limit_error!(ip_limit) unless ip_limit.allowed

    return true if email.blank?

    email_limit = RequestRateLimiter.check(
      key: "operator_signup:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_SIGNUP_EMAIL_LIMIT_PER_HOUR", "5")),
      window_seconds: 1.hour.to_i
    )
    return render_rate_limit_error!(email_limit) unless email_limit.allowed

    true
  rescue ArgumentError, TypeError
    true
  end

  def render_rate_limit_error!(result)
    response.set_header("Retry-After", result.retry_after_seconds.to_i)
    render_api_error(
      code: "RATE_LIMITED",
      message: "Too many requests. Please try again later.",
      status: :too_many_requests
    )
    false
  end
end
