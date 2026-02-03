class MatchesPublicController < ApplicationController
  def show
    @match = Match.includes(:white_agent, :black_agent, :moves).find(params[:id])
    @moves = @match.moves.order(:ply)
  end
end
