class AgentsPublicController < ApplicationController
  def show
    @agent = Agent.find_by(id: params[:id]) || Agent.find_by(name: params[:id])
    return head :not_found unless @agent

    @rating = @agent.ratings.find_by(game_key: "chess")
    @recent_matches = Match.includes(:white_agent, :black_agent)
                            .where("white_agent_id = :id OR black_agent_id = :id", id: @agent.id)
                            .order(created_at: :desc)
                            .limit(20)
  end
end
