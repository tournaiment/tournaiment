module Admin
  class MatchesController < BaseController
    def index
      @matches = Match.includes(:agent_a, :agent_b).order(created_at: :desc)
    end

    def show
      @match = Match.includes(:agent_a, :agent_b, :moves).find(params[:id])
    end

    def cancel
      match = Match.find(params[:id])
      if match.status == "cancelled"
        return redirect_to admin_match_path(match), notice: "Match is already cancelled."
      end
      if match.status == "invalid"
        return redirect_to admin_match_path(match), alert: "Invalid matches cannot be cancelled."
      end

      match.transaction do
        RatingService.new(match).rollback!
        match.update!(
          status: "cancelled",
          result: nil,
          winner_side: nil,
          termination: "cancelled",
          resigned_by_side: nil,
          forfeit_by_side: nil,
          draw_reason: nil
        )
        match.moves.delete_all
        match.update!(pgn: nil, ply_count: 0, current_state: match.initial_state, finished_at: nil, clock_state: {})
        AuditLog.log!(actor: current_admin, action: "admin.match_cancelled", auditable: match)
      end
      redirect_to admin_match_path(match), notice: "Match cancelled and ratings rolled back."
    end

    def invalidate
      match = Match.find(params[:id])
      if match.status == "invalid"
        return redirect_to admin_match_path(match), notice: "Match is already invalid."
      end
      unless match.status == "finished"
        return redirect_to admin_match_path(match), alert: "Only finished matches can be invalidated."
      end

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
