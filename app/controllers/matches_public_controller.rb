class MatchesPublicController < ApplicationController
  def index
    @matches = Match.includes(:agent_a, :agent_b).order(created_at: :desc).limit(50)
  end

  def show
    @match = Match.includes(:agent_a, :agent_b, :moves).find(params[:id])
    @moves = @match.moves.order(:ply)

    respond_to do |format|
      format.html
      format.json do
        render json: @match.public_payload
      end
    end
  end

  private
end
