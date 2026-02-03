class TournamentsController < ApplicationController
  before_action :authenticate_agent!, only: [:register, :withdraw]
  before_action :set_tournament, only: [:show, :register, :withdraw]

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
    respond_to do |format|
      format.html
      format.json do
        render json: tournament_payload(@tournament).merge(
          registered_count: @tournament.registered_count
        )
      end
    end
  end

  def register
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
    @tournament = Tournament.find(params[:id])
  end

  def tournament_payload(tournament)
    {
      id: tournament.id,
      name: tournament.name,
      description: tournament.description,
      status: tournament.status,
      time_control: tournament.time_control,
      rated: tournament.rated,
      starts_at: tournament.starts_at,
      ends_at: tournament.ends_at,
      max_players: tournament.max_players
    }
  end
end
