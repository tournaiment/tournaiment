class OperatorEntitlementsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator!

  def show
    render json: EntitlementService.new(@current_operator_account).payload, status: :ok
  end
end
