class OperatorPortalSessionsController < ApplicationController
  def new
    redirect_to operator_root_path if operator_signed_in?
  end

  def create
    email = normalized_email
    intent = params[:intent].to_s
    if email.blank?
      flash.now[:alert] = "Email is required."
      return render :new, status: :unprocessable_entity
    end

    case intent
    when "request_code", "request_login_otp", "request_email_verification", ""
      return unless enforce_code_request_rate_limits!(email)
      handle_code_request(email)
    when "submit_code", "verify_login_otp", "verify_email"
      return unless enforce_code_submit_rate_limits!(email)
      handle_code_submit(email)
    else
      flash.now[:alert] = "Unsupported login action."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    AuditLog.log!(actor: current_operator_account, action: "operator_account.portal_logout", metadata: { ip: request.remote_ip }) if current_operator_account
    session.delete(:operator_account_id)
    redirect_to operator_login_path, notice: "Signed out."
  end

  private

  def normalized_email
    params[:email].to_s.strip.downcase
  end

  def normalized_code
    (params[:otp].presence || params[:code].presence).to_s.gsub(/\D/, "")[0, 6]
  end

  def handle_code_request(email)
    operator = OperatorAccount.find_by(email: email)
    if operator&.active? && operator.verified_email?
      code = OperatorOtpService.new.issue!(
        operator_account: operator,
        purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
        ip_address: request.remote_ip
      )
      OperatorAuthMailer.login_otp(operator_account: operator, code: code).deliver_now
      AuditLog.log!(actor: operator, action: "operator_account.portal_login_otp_requested", metadata: { ip: request.remote_ip })
      redirect_to operator_login_path(email: email), notice: "A 6-digit code was sent to your email."
    elsif operator&.active?
      code = OperatorOtpService.new.issue!(
        operator_account: operator,
        purpose: OperatorOneTimePasscode::PURPOSE_EMAIL_VERIFICATION,
        ip_address: request.remote_ip
      )
      OperatorAuthMailer.email_verification_otp(operator_account: operator, code: code).deliver_now
      AuditLog.log!(actor: operator, action: "operator_account.portal_email_verification_requested", metadata: { ip: request.remote_ip })
      redirect_to operator_login_path(email: email), notice: "A 6-digit code was sent to your email."
    else
      redirect_to operator_login_path(email: email), notice: "If the account exists, a 6-digit code was sent."
    end
  end

  def handle_code_submit(email)
    code = normalized_code
    if code.blank?
      flash.now[:alert] = "Enter the 6-digit code."
      return render :new, status: :unprocessable_entity
    end

    operator = OperatorAccount.find_by(email: email)
    unless operator&.active?
      AuditLog.log!(actor: operator, action: "operator_account.portal_login_failed", metadata: { ip: request.remote_ip, email: email })
      flash.now[:alert] = "Invalid email or code."
      return render :new, status: :unauthorized
    end

    if operator.verified_email?
      result = OperatorOtpService.new.verify!(
        operator_account: operator,
        purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
        code: code
      )
      unless result.success?
        AuditLog.log!(actor: operator, action: "operator_account.portal_login_failed", metadata: { ip: request.remote_ip, email: email })
        flash.now[:alert] = "Invalid email or code."
        return render :new, status: :unauthorized
      end

      complete_login(operator)
      return
    end

    result = OperatorOtpService.new.verify!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_EMAIL_VERIFICATION,
      code: code
    )
    unless result.success?
      AuditLog.log!(actor: operator, action: "operator_account.portal_login_failed", metadata: { ip: request.remote_ip, email: email })
      flash.now[:alert] = "Invalid email or code."
      return render :new, status: :unauthorized
    end

    operator.update!(email_verified_at: Time.current)
    AuditLog.log!(actor: operator, action: "operator_account.portal_email_verified", metadata: { ip: request.remote_ip })
    complete_login(operator)
  end

  def complete_login(operator)
    session[:operator_account_id] = operator.id
    AuditLog.log!(actor: operator, action: "operator_account.portal_login", metadata: { ip: request.remote_ip })
    redirect_to operator_root_path
  end

  def enforce_code_request_rate_limits!(email)
    operator = OperatorAccount.find_by(email: email)
    if operator&.active? && !operator.verified_email?
      enforce_verification_request_rate_limits!(email)
    else
      enforce_otp_request_rate_limits!(email)
    end
  end

  def enforce_code_submit_rate_limits!(email)
    operator = OperatorAccount.find_by(email: email)
    if operator&.active? && !operator.verified_email?
      enforce_verification_confirm_rate_limits!(email)
    else
      enforce_otp_verify_rate_limits!(email)
    end
  end

  def enforce_otp_request_rate_limits!(email)
    enforce_rate_limit!(
      key: "portal_operator_otp_request:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_REQUEST_IP_LIMIT_PER_15_MIN", "50")),
      window: 15.minutes.to_i
    ) && enforce_rate_limit!(
      key: "portal_operator_otp_request:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_REQUEST_EMAIL_LIMIT_PER_15_MIN", "8")),
      window: 15.minutes.to_i
    )
  rescue ArgumentError, TypeError
    true
  end

  def enforce_otp_verify_rate_limits!(email)
    enforce_rate_limit!(
      key: "portal_operator_otp_verify:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_VERIFY_IP_LIMIT_PER_15_MIN", "120")),
      window: 15.minutes.to_i
    ) && enforce_rate_limit!(
      key: "portal_operator_otp_verify:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_OTP_VERIFY_EMAIL_LIMIT_PER_15_MIN", "25")),
      window: 15.minutes.to_i
    )
  rescue ArgumentError, TypeError
    true
  end

  def enforce_verification_request_rate_limits!(email)
    enforce_rate_limit!(
      key: "portal_operator_verification_request:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_REQUEST_IP_LIMIT_PER_HOUR", "60")),
      window: 1.hour.to_i
    ) && enforce_rate_limit!(
      key: "portal_operator_verification_request:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_REQUEST_EMAIL_LIMIT_PER_HOUR", "10")),
      window: 1.hour.to_i
    )
  rescue ArgumentError, TypeError
    true
  end

  def enforce_verification_confirm_rate_limits!(email)
    enforce_rate_limit!(
      key: "portal_operator_verification_confirm:ip:#{request.remote_ip}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_CONFIRM_IP_LIMIT_PER_HOUR", "120")),
      window: 1.hour.to_i
    ) && enforce_rate_limit!(
      key: "portal_operator_verification_confirm:email:#{email}",
      limit: Integer(ENV.fetch("OPERATOR_VERIFICATION_CONFIRM_EMAIL_LIMIT_PER_HOUR", "30")),
      window: 1.hour.to_i
    )
  rescue ArgumentError, TypeError
    true
  end

  def enforce_rate_limit!(key:, limit:, window:)
    result = RequestRateLimiter.check(key: key, limit: limit, window_seconds: window)
    return true if result.allowed

    response.set_header("Retry-After", result.retry_after_seconds.to_i)
    flash.now[:alert] = "Too many attempts. Please try again later."
    render :new, status: :too_many_requests
    false
  end
end
