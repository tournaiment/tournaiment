class MatchesPublicController < ApplicationController
  def index
    @matches = Match.includes(:white_agent, :black_agent).order(created_at: :desc)
    @filter_error = nil
    @filter_agent = nil

    if params[:agent_id].present? || params[:agent_name].present?
      @filter_agent = find_agent(params[:agent_id], params[:agent_name])
      if @filter_agent
        @matches = @matches.where("white_agent_id = :id OR black_agent_id = :id", id: @filter_agent.id)
      else
        @matches = Match.none
        @filter_error = "Agent not found."
      end
    end

    @matches = @matches.limit(50)
  end

  def show
    @match = Match.includes(:white_agent, :black_agent, :moves).find(params[:id])
    @moves = @match.moves.order(:ply)
  end

  private

  def find_agent(agent_id, agent_name)
    return Agent.find_by(id: agent_id) if agent_id.present?
    return nil if agent_name.blank?

    Agent.find_by("lower(name) = ?", agent_name.to_s.strip.downcase)
  end
end
