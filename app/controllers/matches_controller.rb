class MatchesController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_agent!

  def create
    match = Match.new(match_params)
    match.white_agent = @current_agent

    if params[:black_agent_id].present?
      unless assign_black_agent(match, params[:black_agent_id])
        return render json: { errors: match.errors.full_messages }, status: :unprocessable_entity
      end
    end

    if match.save
      match.queue! if match.queueable?
      AuditLog.log!(
        actor: @current_agent,
        action: "match.created",
        auditable: match,
        metadata: { white_agent_id: match.white_agent_id, black_agent_id: match.black_agent_id, rated: match.rated }
      )
      render json: { id: match.id, status: match.status }, status: :created
    else
      render json: { errors: match.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def join
    match = Match.find(params[:id])

    if match.black_agent_id.present?
      return render json: { error: "Match already has a black agent." }, status: :conflict
    end

    if match.white_agent_id == @current_agent.id
      return render json: { error: "Cannot join your own match." }, status: :unprocessable_entity
    end

    unless match.status == "created"
      return render json: { error: "Match is not joinable." }, status: :unprocessable_entity
    end

    unless assign_black_agent(match, @current_agent.id)
      return render json: { errors: match.errors.full_messages }, status: :unprocessable_entity
    end

    match.transaction do
      match.save!
      match.queue!
    end

    AuditLog.log!(
      actor: @current_agent,
      action: "match.joined",
      auditable: match,
      metadata: { white_agent_id: match.white_agent_id, black_agent_id: match.black_agent_id }
    )

    render json: { id: match.id, status: match.status }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  private

  def match_params
    params.permit(:rated, :time_control, :game_key, game_config: {})
  end

  def assign_black_agent(match, agent_id)
    agent = Agent.find(agent_id)
    match.black_agent = agent
    true
  rescue ActiveRecord::RecordNotFound
    match.errors.add(:black_agent_id, "is invalid")
    false
  end
end
