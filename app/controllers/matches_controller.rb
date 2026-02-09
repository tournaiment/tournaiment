class MatchesController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_agent!

  def create
    if params[:tournament_id].present?
      return render json: { errors: [ "tournament_id cannot be set via this endpoint" ] }, status: :unprocessable_entity
    end

    match = Match.new(match_params)
    match.agent_a = @current_agent
    assign_time_control_preset(match)
    if match.errors.any?
      return render json: { errors: match.errors.full_messages }, status: :unprocessable_entity
    end
    return if enforce_ranked_access_for_match!(match)

    agent_b_id = params[:agent_b_id].presence || params[:black_agent_id].presence
    if agent_b_id.present?
      unless assign_agent_b(match, agent_b_id)
        return render json: { errors: match.errors.full_messages }, status: :unprocessable_entity
      end
    end

    if match.save
      match.queue! if match.queueable?
      AuditLog.log!(
        actor: @current_agent,
        action: "match.created",
        auditable: match,
        metadata: { agent_a_id: match.agent_a_id, agent_b_id: match.agent_b_id, rated: match.rated }
      )
      render json: { id: match.id, status: match.status }, status: :created
    else
      render json: { errors: match.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def join
    match = Match.find(params[:id])
    return if enforce_ranked_access_for_match!(match)

    if match.agent_b_id.present?
      return render json: { error: "Match already has an opponent B." }, status: :conflict
    end

    if match.agent_a_id == @current_agent.id
      return render json: { error: "Cannot join your own match." }, status: :unprocessable_entity
    end

    unless match.status == "created"
      return render json: { error: "Match is not joinable." }, status: :unprocessable_entity
    end

    unless assign_agent_b(match, @current_agent.id)
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
      metadata: { agent_a_id: match.agent_a_id, agent_b_id: match.agent_b_id }
    )

    render json: { id: match.id, status: match.status }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  end

  private

  def enforce_ranked_access_for_match!(match)
    return false unless match.rated?
    return false if EntitlementService.new(@current_agent.operator_account).ranked_enabled?

    render_api_error(
      code: "PLAN_REQUIRED_RANKED",
      message: "Ranked play requires a pro plan.",
      status: :forbidden,
      required: [ "pro_plan" ]
    )
    true
  end

  def match_params
    params.permit(:rated, :time_control, :game_key, :time_control_preset_id, :time_control_preset_key, game_config: {})
  end

  def assign_agent_b(match, agent_id)
    agent = Agent.find(agent_id)
    match.agent_b = agent
    true
  rescue ActiveRecord::RecordNotFound
    match.errors.add(:agent_b_id, "is invalid")
    false
  end

  def assign_time_control_preset(match)
    preset_id = params[:time_control_preset_id].presence
    preset_key = params[:time_control_preset_key].presence
    return if preset_id.blank? && preset_key.blank?

    preset = TimeControlPreset.resolve!(id: preset_id, key: preset_key)
    match.time_control_preset = preset
    match.game_key = preset.game_key if match.game_key.blank?
    match.time_control = preset.category
  rescue ActiveRecord::RecordNotFound
    match.errors.add(:time_control_preset_id, "is invalid")
  end
end
