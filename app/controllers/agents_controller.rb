class AgentsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator!

  def create
    entitlement = EntitlementService.new(@current_operator_account)
    unless entitlement.can_create_agent?
      return render_api_error(
        code: "AGENT_SEAT_REQUIRED",
        message: "No available agent seats. Upgrade to pro and add seats.",
        status: :forbidden,
        required: [ "pro_plan_with_seat_addon" ]
      )
    end

    agent = Agent.new(agent_params)
    agent.operator_account = @current_operator_account
    agent.status = "active"
    raw_key = Agent.generate_api_key
    agent.api_key = raw_key
    agent.api_key_hash = Agent.api_key_hash(raw_key)
    agent.api_key_last_rotated_at = Time.current
    unless validate_metadata_endpoints!(agent)
      return render json: { errors: agent.errors.full_messages }, status: :unprocessable_entity
    end

    if agent.save
      AuditLog.log!(
        actor: @current_operator_account,
        action: "agent.registered",
        auditable: agent,
        metadata: { ip: request.remote_ip, operator_account_id: @current_operator_account.id }
      )

      render json: { id: agent.id, api_key: raw_key, status: agent.status, entitlements: entitlement.payload }, status: :created
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

  def validate_metadata_endpoints!(agent)
    metadata = agent.metadata.is_a?(Hash) ? agent.metadata : {}
    move_endpoint = metadata_value(metadata, "move_endpoint").to_s.strip
    if move_endpoint.blank?
      agent.errors.add(:metadata, "move_endpoint is required")
      return false
    end

    AgentEndpointPolicy.validate_move_endpoint!(move_endpoint)

    tournament_endpoint = metadata_value(metadata, "tournament_endpoint").to_s.strip
    AgentEndpointPolicy.validate_tournament_endpoint!(tournament_endpoint) if tournament_endpoint.present?
    true
  rescue AgentEndpointPolicy::InvalidEndpoint => e
    agent.errors.add(:metadata, e.message)
    false
  end

  def metadata_value(metadata, key)
    metadata[key] || metadata[key.to_sym]
  end
end
