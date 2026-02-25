class TournamentsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :handle_tournament_not_found

  before_action :authenticate_agent!, only: [ :register, :withdraw ]
  before_action :set_tournament, only: [ :show, :register, :withdraw, :bracket, :table ]

  def index
    @tournaments = Tournament.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json do
        render json: @tournaments.map { |t| tournament_payload(t) }
      end
    end
  end

  def show
    @bracket_rounds = load_bracket_rounds
    @standings = TournamentStandingsService.new(@tournament).call

    respond_to do |format|
      format.html
      format.json do
        render json: tournament_payload(@tournament).merge(
          registered_count: @tournament.registered_count,
          rounds: bracket_payload,
          standings: standings_payload
        )
      end
    end
  end

  def bracket
    @bracket_rounds = load_bracket_rounds
  end

  def table
    @standings = TournamentStandingsService.new(@tournament).call
  end

  def register
    entitlement = EntitlementService.new(@current_agent.operator_account)
    if @tournament.monied? && !entitlement.pro?
      return render_api_error(
        code: "PLAN_REQUIRED_MONIED_TOURNAMENT",
        message: "Cash prize tournament participation requires a paid pro plan.",
        status: :forbidden,
        required: [ "pro_plan" ]
      )
    end

    unless entitlement.tournaments_enabled?
      return render_api_error(
        code: "PLAN_REQUIRED_TOURNAMENT",
        message: "Tournament participation requires a pro plan.",
        status: :forbidden,
        required: [ "pro_plan" ]
      )
    end

    unless @tournament.registration_open?
      return render json: { error: "Registration is closed." }, status: :unprocessable_entity
    end

    if @tournament.max_players.present? && @tournament.registered_count >= @tournament.max_players
      return render json: { error: "Tournament is full." }, status: :conflict
    end

    entry = TournamentEntry.find_or_initialize_by(tournament: @tournament, agent: @current_agent)
    entry.status = "registered"

    if entry.save
      AuditLog.log!(
        actor: @current_agent,
        action: "tournament.registered",
        auditable: @tournament,
        metadata: { agent_id: @current_agent.id }
      )
      render json: { tournament_id: @tournament.id, status: entry.status }, status: :ok
    else
      render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def withdraw
    entry = TournamentEntry.find_by(tournament: @tournament, agent: @current_agent)
    return render json: { error: "Not registered." }, status: :not_found unless entry

    entry.update!(status: "withdrawn")
    AuditLog.log!(
      actor: @current_agent,
      action: "tournament.withdrawn",
      auditable: @tournament,
      metadata: { agent_id: @current_agent.id }
    )
    render json: { tournament_id: @tournament.id, status: entry.status }, status: :ok
  end

  private

  def set_tournament
    @tournament = Tournament.find(Tournament.id_from_param!(params[:id]))
  end

  def handle_tournament_not_found
    respond_to do |format|
      format.html { redirect_to tournaments_path, alert: "Tournament not found. It may have been removed." }
      format.json do
        render_api_error(
          code: "TOURNAMENT_NOT_FOUND",
          message: "Tournament not found.",
          status: :not_found
        )
      end
    end
  end

  def load_bracket_rounds
    @tournament.tournament_rounds
      .includes(tournament_pairings: [ :agent_a, :agent_b, :winner_agent, :match ])
      .order(:round_number)
  end

  def bracket_payload
    load_bracket_rounds.map do |round|
      {
        round_number: round.round_number,
        status: round.status,
        pairings: round.tournament_pairings.sort_by(&:slot).map do |pairing|
          {
            slot: pairing.slot,
            status: pairing.status,
            bye: pairing.bye,
            agent_a: pairing.agent_a&.name,
            agent_b: pairing.agent_b&.name,
            winner: pairing.winner_agent&.name,
            match_id: pairing.match&.id,
            match_result: pairing.match&.result
          }
        end
      }
    end
  end

  def standings_payload
    TournamentStandingsService.new(@tournament).call.map do |row|
      {
        agent_id: row.agent.id,
        agent_name: row.agent.name,
        seed: row.seed,
        played: row.played,
        wins: row.wins,
        draws: row.draws,
        losses: row.losses,
        points: row.points
      }
    end
  end

  def tournament_payload(tournament)
    {
      id: tournament.id,
      name: tournament.name,
      description: tournament.description,
      status: tournament.status,
      format: tournament.format,
      game_key: tournament.game_key,
      time_control: tournament.time_control,
      time_zone: tournament.time_zone,
      locked_time_control_preset_key: tournament.locked_time_control_preset&.key,
      allowed_time_control_preset_keys: tournament.allowed_time_control_presets.order(:key).pluck(:key),
      rated: tournament.rated,
      monied: tournament.monied,
      starts_at: tournament.starts_at,
      ends_at: tournament.ends_at,
      max_players: tournament.max_players
    }
  end
end
