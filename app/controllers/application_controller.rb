class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_admin, :admin_signed_in?, :current_agent, :current_operator_account, :operator_signed_in?, :google_oauth_enabled?

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
    return render_api_error(code: "EMAIL_NOT_VERIFIED", message: "Operator email is not verified.", status: :forbidden) unless account.verified_email?

    @current_operator_account = account
  end

  def current_operator_account
    return @current_operator_account if defined?(@current_operator_account)

    @current_operator_account = OperatorAccount.find_by(id: session[:operator_account_id])
  end

  def operator_signed_in?
    account = current_operator_account
    account.present? && account.active? && account.verified_email?
  end

  def require_operator_session!
    return if operator_signed_in?

    session.delete(:operator_account_id)
    redirect_to operator_login_path, alert: "Please sign in."
  end

  def google_oauth_enabled?
    GoogleOauthClient.new.configured?
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

  def paginate_scope(scope, default_per_page: 25, max_per_page: 100, page_param: :page, per_page_param: :per_page)
    page = positive_integer_param(page_param, default: 1)
    per_page = positive_integer_param(per_page_param, default: default_per_page)
    per_page = [ per_page, max_per_page ].min

    total_count = scope.count
    total_pages = (total_count.to_f / per_page).ceil
    page = [ page, [ total_pages, 1 ].max ].min
    offset = (page - 1) * per_page

    records = scope.limit(per_page).offset(offset)
    meta = pagination_meta(page: page, per_page: per_page, total_count: total_count, total_pages: total_pages, offset: offset)
    [ records, meta ]
  end

  def paginate_array(items, default_per_page: 25, max_per_page: 100, page_param: :page, per_page_param: :per_page)
    page = positive_integer_param(page_param, default: 1)
    per_page = positive_integer_param(per_page_param, default: default_per_page)
    per_page = [ per_page, max_per_page ].min

    total_count = items.length
    total_pages = (total_count.to_f / per_page).ceil
    page = [ page, [ total_pages, 1 ].max ].min
    offset = (page - 1) * per_page

    records = items.slice(offset, per_page) || []
    meta = pagination_meta(page: page, per_page: per_page, total_count: total_count, total_pages: total_pages, offset: offset)
    [ records, meta ]
  end

  def positive_integer_param(key, default:)
    value = params[key].to_i
    value.positive? ? value : default
  end

  def pagination_meta(page:, per_page:, total_count:, total_pages:, offset:)
    {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      offset: offset
    }
  end
end
