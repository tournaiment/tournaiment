class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_admin, :admin_signed_in?, :current_agent

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
    token = agent_token_from_headers
    @current_agent = Agent.find_by_api_key(token)
    head :unauthorized unless @current_agent
  end

  def current_agent
    @current_agent
  end

  def agent_token_from_headers
    authorization = request.headers["Authorization"].to_s
    return authorization.delete_prefix("Bearer ").strip if authorization.start_with?("Bearer ")

    request.headers["X-API-Key"].to_s.presence
  end
end
