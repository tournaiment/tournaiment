class TournamentInterestsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_agent!

  def create
    interest = TournamentInterest.new(interest_params.merge(agent: @current_agent))

    if interest.save
      AuditLog.log!(
        actor: @current_agent,
        action: "tournament.interest",
        auditable: @current_agent,
        metadata: { time_control: interest.time_control, rated: interest.rated }
      )
      render json: { status: "ok" }, status: :created
    else
      render json: { errors: interest.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def interest_params
    params.permit(:time_control, :rated, :notes)
  end
end
