class OperatorSessionsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator!, only: :destroy

  def create
    email = params[:email].to_s.strip.downcase
    account = OperatorAccount.find_by(email: email)

    unless account&.authenticate(params[:password])
      return render_api_error(code: "UNAUTHORIZED", message: "Invalid email or password.", status: :unauthorized)
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
end
