class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_admin, :admin_signed_in?, :current_agent, :current_operator_account, :operator_signed_in?

  private

  def current_admin
    return @current_admin if defined?(@current_admin)

    @current_admin = AdminUser.find_by(id: session[:admin_id])
  end

  def admin_signed_in?
    current_admin.present?
  end

  def require_admin!
    return if admin_signed_in?

    redirect_to admin_login_path, alert: "Please sign in."
  end

  def authenticate_agent!
    token = auth_token_from_headers
    agent = Agent.find_by_api_key(token)
    return render_api_error(code: "UNAUTHORIZED", message: "Invalid or missing agent API key.", status: :unauthorized) unless agent
    return render_api_error(code: "AGENT_SUSPENDED", message: "Agent is suspended and cannot perform this action.", status: :forbidden) unless agent.active?

    @current_agent = agent
  end

  def current_agent
    @current_agent
  end

  def authenticate_operator!
    token = auth_token_from_headers
    account = OperatorAccount.find_by_api_token(token)
    return render_api_error(code: "UNAUTHORIZED", message: "Invalid or missing operator API key.", status: :unauthorized) unless account
    return render_api_error(code: "OPERATOR_SUSPENDED", message: "Operator account is suspended.", status: :forbidden) unless account.active?

    @current_operator_account = account
  end

  def current_operator_account
    return @current_operator_account if defined?(@current_operator_account)

    @current_operator_account = OperatorAccount.find_by(id: session[:operator_account_id])
  end

  def operator_signed_in?
    current_operator_account.present?
  end

  def require_operator_session!
    return if operator_signed_in?

    redirect_to operator_login_path, alert: "Please sign in."
  end

  def auth_token_from_headers
    authorization = request.headers["Authorization"].to_s
    return authorization.delete_prefix("Bearer ").strip if authorization.start_with?("Bearer ")

    request.headers["X-API-Key"].to_s.presence || request.headers["X-Operator-Key"].to_s.presence
  end

  def render_api_error(code:, message:, status:, required: nil)
    payload = { error: { code: code, message: message } }
    payload[:error][:required] = required if required.present?
    render json: payload, status: status
  end
end
