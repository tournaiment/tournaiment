class OperatorEmailVerificationsController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    email = normalized_email
    return render_api_error(code: "INVALID_EMAIL", message: "Email is required.", status: :unprocessable_entity) if email.blank?
    return unless enforce_request_rate_limits!(email)

    account = OperatorAccount.find_by(email: email)
    if account&.active? && !account.verified_email?
      code = OperatorOtpService.new.issue!(
        operator_account: account,
        purpose: OperatorOneTimePasscode::PURPOSE_EMAIL_VERIFICATION,
        ip_address: request.remote_ip
      )
      OperatorAuthMailer.email_verification_otp(operator_account: account, code: code).deliver_now
      AuditLog.log!(actor: account, action: "operator_account.email_verification_requested", metadata: { ip: request.remote_ip })
    end

    render json: { status: "verification_code_sent", delivery: "email" }, status: :accepted
  end

  def confirm
    email = normalized_email
    code = normalized_code
    return render_api_error(code: "INVALID_EMAIL", message: "Email is required.", status: :unprocessable_entity) if email.blank?
    return render_api_error(code: "INVALID_VERIFICATION_CODE", message: "A 6-digit verification code is required.", status: :unprocessable_entity) if code.blank?
    return unless enforce_confirm_rate_limits!(email)

    account = OperatorAccount.find_by(email: email)
    unless account&.active?
      return render_api_error(code: "UNAUTHORIZED", message: "Invalid email or verification code.", status: :unauthorized)
    end

    if account.verified_email?
      return render json: {
        status: "verified",
        email_verified_at: account.email_verified_at
      }, status: :ok
    end

    result = OperatorOtpService.new.verify!(
      operator_account: account,
      purpose: OperatorOneTimePasscode::PURPOSE_EMAIL_VERIFICATION,
      code: code
    )
    unless result.success?
      return render_api_error(code: "UNAUTHORIZED", message: "Invalid email or verification code.", status: :unauthorized)
    end

    account.update!(email_verified_at: Time.current)
    AuditLog.log!(actor: account, action: "operator_account.email_verified", metadata: { ip: request.remote_ip })
    render json: {
      status: "verified",
      email_verified_at: account.email_verified_at
    }, status: :ok
  end

  private

  def normalized_email
    params[:email].to_s.strip.downcase
  end

  def normalized_code
    (params[:otp].presence || params[:code].presence).to_s.gsub(/\D/, "")[0, 6]
  end

  def enforce_request_rate_limits!(email)
    ip_limit = RequestRateLimiter.check(
      key: "operator_verification_request:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_REQUEST_IP_LIMIT_PER_HOUR", "60")),
      window_seconds: 1.hour.to_i
    )
    return render_rate_limit_error!(ip_limit) unless ip_limit.allowed

    email_limit = RequestRateLimiter.check(
      key: "operator_verification_request:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_REQUEST_EMAIL_LIMIT_PER_HOUR", "10")),
      window_seconds: 1.hour.to_i
    )
    return render_rate_limit_error!(email_limit) unless email_limit.allowed

    true
  rescue ArgumentError, TypeError
    true
  end

  def enforce_confirm_rate_limits!(email)
    ip_limit = RequestRateLimiter.check(
      key: "operator_verification_confirm:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_CONFIRM_IP_LIMIT_PER_HOUR", "120")),
      window_seconds: 1.hour.to_i
    )
    return render_rate_limit_error!(ip_limit) unless ip_limit.allowed

    email_limit = RequestRateLimiter.check(
      key: "operator_verification_confirm:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_CONFIRM_EMAIL_LIMIT_PER_HOUR", "30")),
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
