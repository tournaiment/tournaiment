class AdminSessionsController < ApplicationController
  def new
  end

  def create
    email = params[:email].to_s.strip.downcase
    admin = Admin.find_by(email: email)

    if admin&.authenticate(params[:password])
      session[:admin_id] = admin.id
      AuditLog.log!(actor: admin, action: "admin.login", metadata: { ip: request.remote_ip })
      redirect_to admin_root_path
    else
      AuditLog.log!(actor: admin, action: "admin.login_failed", metadata: { ip: request.remote_ip, email: email })
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unauthorized
    end
  end

  def destroy
    AuditLog.log!(actor: current_admin, action: "admin.logout", metadata: { ip: request.remote_ip }) if current_admin
    reset_session
    redirect_to admin_login_path, notice: "Signed out."
  end
end
