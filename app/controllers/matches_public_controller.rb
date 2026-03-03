class MatchesPublicController < ApplicationController
  def index
    scope = Match.includes(:agent_a, :agent_b).order(created_at: :desc)
    @matches, @matches_pagination = paginate_scope(scope, default_per_page: 30, max_per_page: 100)
  end

  def show
    @match = Match.includes(:agent_a, :agent_b, :moves).find_by(id: params[:id])
    return render_match_not_found unless @match

    @moves = @match.moves.order(:ply)

    respond_to do |format|
      format.html
      format.json do
        render json: @match.public_payload
      end
    end
  end

  private

  def render_match_not_found
    respond_to do |format|
      format.html { redirect_to public_matches_path, alert: "Match not found." }
      format.json { render json: { error: "Match not found." }, status: :not_found }
      format.any { head :not_found }
    end
  end
end
