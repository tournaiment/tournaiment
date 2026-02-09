class OperatorOauthController < ApplicationController
  STATE_SESSION_KEY = :operator_google_oauth_state

  def google_start
    client = GoogleOauthClient.new
    unless client.configured?
      return redirect_to operator_login_path, alert: "Google OAuth is not configured."
    end

    state = SecureRandom.hex(24)
    session[STATE_SESSION_KEY] = state
    redirect_to client.authorization_url(state: state), allow_other_host: true
  end

  def google_callback
    state = params[:state].to_s
    expected_state = session.delete(STATE_SESSION_KEY).to_s
    unless state.present? && secure_compare(state, expected_state)
      return redirect_to operator_login_path, alert: "Invalid Google OAuth state."
    end

    client = GoogleOauthClient.new
    unless client.configured?
      return redirect_to operator_login_path, alert: "Google OAuth is not configured."
    end

    email = client.exchange_code_for_verified_email!(params[:code].to_s)
    operator = find_or_create_operator_from_google!(email)
    return redirect_to operator_login_path, alert: "Operator account is suspended." unless operator.active?

    session[:operator_account_id] = operator.id
    operator.update!(email_verified_at: Time.current) unless operator.verified_email?
    AuditLog.log!(actor: operator, action: "operator_account.google_oauth_login", metadata: { ip: request.remote_ip })
    redirect_to operator_root_path, notice: "Signed in with Google."
  rescue GoogleOauthClient::Error => e
    redirect_to operator_login_path, alert: "Google sign-in failed: #{e.message}"
  end

  private

  def find_or_create_operator_from_google!(email)
    operator = OperatorAccount.find_by(email: email)
    return operator if operator

    OperatorAccount.create!(
      email: email,
      email_verified_at: Time.current
    ).tap do |account|
      AuditLog.log!(actor: account, action: "operator_account.created_via_google_oauth", metadata: { ip: request.remote_ip })
    end
  end

  def secure_compare(actual, expected)
    return false if actual.blank? || expected.blank?
    return false unless actual.bytesize == expected.bytesize

    ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end
end
