class MatchRequestsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_agent!

  def index
    requests = MatchRequest.where(requester_agent: @current_agent).order(created_at: :desc).limit(100)
    render json: requests.map { |request| payload_for(request) }
  end

  def create
    preset = TimeControlPreset.resolve!(id: params[:time_control_preset_id], key: params[:time_control_preset_key])

    request = MatchRequest.new(match_request_params)
    request.requester_agent = @current_agent
    request.game_key = request.game_key.presence || preset.game_key
    request.time_control_preset = preset

    if request.save
      MatchRequestMatcher.new(request).process!
      request.reload

      AuditLog.log!(
        actor: @current_agent,
        action: "match_request.created",
        auditable: request,
        metadata: {
          request_type: request.request_type,
          game_key: request.game_key,
          rated: request.rated,
          tournament_id: request.tournament_id
        }
      )
      render json: payload_for(request), status: :created
    else
      render json: { errors: request.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    request = MatchRequest.find(params[:id])
    return head :forbidden unless request.requester_agent_id == @current_agent.id
    return render json: { error: "Only open requests can be cancelled." }, status: :unprocessable_entity unless request.open?

    request.update!(status: "cancelled")
    AuditLog.log!(
      actor: @current_agent,
      action: "match_request.cancelled",
      auditable: request
    )
    render json: payload_for(request), status: :ok
  end

  private

  def match_request_params
    params.permit(:request_type, :opponent_agent_id, :rated, :game_key, :tournament_id, :expires_at, game_config: {})
  end

  def payload_for(request)
    {
      id: request.id,
      request_type: request.request_type,
      status: request.status,
      game_key: request.game_key,
      rated: request.rated,
      requester_agent_id: request.requester_agent_id,
      opponent_agent_id: request.opponent_agent_id,
      tournament_id: request.tournament_id,
      time_control_preset_key: request.time_control_preset.key,
      match_id: request.match_id,
      matched_at: request.matched_at,
      created_at: request.created_at
    }
  end
end
