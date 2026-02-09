class OperatorSessionsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator!, only: :destroy

  def request_otp
    email = normalized_email
    return render_api_error(code: "INVALID_EMAIL", message: "Email is required.", status: :unprocessable_entity) if email.blank?
    return unless enforce_otp_request_rate_limits!(email)

    account = OperatorAccount.find_by(email: email)
    if account&.active? && account.verified_email?
      code = OperatorOtpService.new.issue!(
        operator_account: account,
        purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
        ip_address: request.remote_ip
      )
      OperatorAuthMailer.login_otp(operator_account: account, code: code).deliver_now
      AuditLog.log!(actor: account, action: "operator_account.login_otp_requested", metadata: { ip: request.remote_ip })
    end

    render json: { status: "otp_sent", delivery: "email" }, status: :accepted
  end

  def create
    email = normalized_email
    otp = normalized_code
    return render_api_error(code: "INVALID_LOGIN_OTP", message: "A 6-digit one-time code is required.", status: :unprocessable_entity) if otp.blank?
    return unless enforce_otp_verify_rate_limits!(email)

    account = OperatorAccount.find_by(email: email)

    unless account&.active?
      return render_api_error(code: "UNAUTHORIZED", message: "Invalid email or one-time code.", status: :unauthorized)
    end

    unless account.verified_email?
      return render_api_error(
        code: "EMAIL_NOT_VERIFIED",
        message: "Email is not verified. Verify your email before requesting a login code.",
        status: :forbidden
      )
    end

    result = OperatorOtpService.new.verify!(
      operator_account: account,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: otp
    )
    unless result.success?
      return render_api_error(code: "UNAUTHORIZED", message: "Invalid email or one-time code.", status: :unauthorized)
    end

    raw_token = account.rotate_api_token!
    AuditLog.log!(actor: account, action: "operator_account.login", metadata: { ip: request.remote_ip })
    render json: {
      id: account.id,
      email: account.email,
      api_token: raw_token,
      entitlements: EntitlementService.new(account).payload
    }, status: :ok
  end

  def destroy
    @current_operator_account.rotate_api_token!
    AuditLog.log!(actor: @current_operator_account, action: "operator_account.logout", metadata: { ip: request.remote_ip })
    head :no_content
  end

  private

  def normalized_email
    params[:email].to_s.strip.downcase
  end

  def normalized_code
    (params[:otp].presence || params[:code].presence).to_s.gsub(/\D/, "")[0, 6]
  end

  def enforce_otp_request_rate_limits!(email)
    ip_limit = RequestRateLimiter.check(
      key: "operator_otp_request:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_REQUEST_IP_LIMIT_PER_15_MIN", "50")),
      window_seconds: 15.minutes.to_i
    )
    return render_rate_limit_error!(ip_limit) unless ip_limit.allowed

    email_limit = RequestRateLimiter.check(
      key: "operator_otp_request:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_REQUEST_EMAIL_LIMIT_PER_15_MIN", "8")),
      window_seconds: 15.minutes.to_i
    )
    return render_rate_limit_error!(email_limit) unless email_limit.allowed

    true
  rescue ArgumentError, TypeError
    true
  end

  def enforce_otp_verify_rate_limits!(email)
    ip_limit = RequestRateLimiter.check(
      key: "operator_otp_verify:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_VERIFY_IP_LIMIT_PER_15_MIN", "120")),
      window_seconds: 15.minutes.to_i
    )
    return render_rate_limit_error!(ip_limit) unless ip_limit.allowed

    email_limit = RequestRateLimiter.check(
      key: "operator_otp_verify:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_VERIFY_EMAIL_LIMIT_PER_15_MIN", "25")),
      window_seconds: 15.minutes.to_i
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
