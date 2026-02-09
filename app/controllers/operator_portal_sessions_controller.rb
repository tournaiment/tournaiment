class OperatorPortalSessionsController < ApplicationController
  def new
    redirect_to operator_root_path if operator_signed_in?
  end

  def create
    email = params[:email].to_s.strip.downcase
    operator = OperatorAccount.find_by(email: email)

    if operator&.authenticate(params[:password]) && operator.active?
      session[:operator_account_id] = operator.id
      AuditLog.log!(actor: operator, action: "operator_account.portal_login", metadata: { ip: request.remote_ip })
      redirect_to operator_root_path
    else
      AuditLog.log!(actor: operator, action: "operator_account.portal_login_failed", metadata: { ip: request.remote_ip, email: email })
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unauthorized
    end
  end

  def destroy
    AuditLog.log!(actor: current_operator_account, action: "operator_account.portal_logout", metadata: { ip: request.remote_ip }) if current_operator_account
    session.delete(:operator_account_id)
    redirect_to operator_login_path, notice: "Signed out."
  end
end
