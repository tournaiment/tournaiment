class OperatorAccountsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator!, only: :show

  def create
    account = OperatorAccount.new(operator_account_params)
    account.email_verified_at = Time.current
    raw_token = OperatorAccount.generate_api_token
    account.api_token = raw_token
    account.api_token_hash = OperatorAccount.api_token_hash(raw_token)
    account.api_token_last_rotated_at = Time.current

    if account.save
      AuditLog.log!(actor: account, action: "operator_account.created", metadata: { ip: request.remote_ip })
      render json: payload_for(account).merge(api_token: raw_token), status: :created
    else
      render json: { errors: account.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: payload_for(@current_operator_account)
  end

  private

  def operator_account_params
    params.require(:operator_account).permit(:email, :password, :password_confirmation)
  rescue ActionController::ParameterMissing
    params.permit(:email, :password, :password_confirmation)
  end

  def payload_for(account)
    {
      id: account.id,
      email: account.email,
      status: account.status,
      email_verified_at: account.email_verified_at,
      entitlements: EntitlementService.new(account).payload
    }
  end
end
