class MatchesPublicController < ApplicationController
  def index
    @matches = Match.includes(:white_agent, :black_agent).order(created_at: :desc).limit(50)
  end

  def show
    @match = Match.includes(:white_agent, :black_agent, :moves).find(params[:id])
    @moves = @match.moves.order(:ply)
  end
end
