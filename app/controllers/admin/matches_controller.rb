module Admin
  class MatchesController < BaseController
    def index
      @matches = Match.includes(:white_agent, :black_agent).order(created_at: :desc)
    end

    def show
      @match = Match.includes(:white_agent, :black_agent, :moves).find(params[:id])
    end

    def cancel
      match = Match.find(params[:id])
      match.transaction do
        RatingService.new(match).rollback!
        match.update!(status: "cancelled", result: nil, winner_color: nil, termination: "cancelled")
        match.moves.delete_all
        match.update!(pgn: nil, ply_count: 0, current_fen: match.initial_fen, finished_at: nil)
        AuditLog.log!(actor: current_admin, action: "admin.match_cancelled", auditable: match)
      end
      redirect_to admin_match_path(match), notice: "Match cancelled and ratings rolled back."
    end

    def invalidate
      match = Match.find(params[:id])
      match.transaction do
        RatingService.new(match).rollback!
        match.update!(status: "invalid", termination: "invalid")
        match.update!(pgn: nil)
        AuditLog.log!(actor: current_admin, action: "admin.match_invalidated", auditable: match)
      end
      redirect_to admin_match_path(match), notice: "Match invalidated and ratings rolled back."
    end
  end
end
