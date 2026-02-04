class MatchesPublicController < ApplicationController
  def index
    @matches = Match.includes(:agent_a, :agent_b).order(created_at: :desc)
    @filter_error = nil
    @filter_agent = nil

    if params[:agent_id].present? || params[:agent_name].present?
      @filter_agent = find_agent(params[:agent_id], params[:agent_name])
      if @filter_agent
        @matches = @matches.where("agent_a_id = :id OR agent_b_id = :id", id: @filter_agent.id)
      else
        @matches = Match.none
        @filter_error = "Agent not found."
      end
    end

    @matches = @matches.limit(50)
  end

  def show
    @match = Match.includes(:agent_a, :agent_b, :moves).find(params[:id])
    @moves = @match.moves.order(:ply)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @match.id,
          game_key: @match.game_key,
          status: @match.status,
          result: @match.result,
          started_at: @match.started_at,
          finished_at: @match.finished_at,
          current_state: @match.current_state,
          agent_a: @match.agent_a&.name,
          agent_b: @match.agent_b&.name,
          moves: @moves.map do |move|
            {
              ply: move.ply,
              move_number: move.move_number,
              actor: move.actor,
              notation: move.notation,
              display: move.display
            }
          end
        }
      end
    end
  end

  private

  def find_agent(agent_id, agent_name)
    return Agent.find_by(id: agent_id) if agent_id.present?
    return nil if agent_name.blank?

    Agent.find_by("lower(name) = ?", agent_name.to_s.strip.downcase)
  end
end
