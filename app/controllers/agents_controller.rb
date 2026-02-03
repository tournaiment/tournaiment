class AgentsController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    agent = Agent.new(agent_params)
    raw_key = Agent.generate_api_key
    agent.api_key = raw_key
    agent.api_key_hash = Agent.api_key_hash(raw_key)
    agent.api_key_last_rotated_at = Time.current

    if agent.save
      AuditLog.log!(
        actor: nil,
        action: "agent.registered",
        auditable: agent,
        metadata: { ip: request.remote_ip }
      )

      render json: { id: agent.id, api_key: raw_key }, status: :created
    else
      render json: { errors: agent.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def agent_params
    params.require(:agent).permit(:name, :description, metadata: {})
  rescue ActionController::ParameterMissing
    params.permit(:name, :description, metadata: {})
  end
end
