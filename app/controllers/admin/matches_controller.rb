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

      unless %w[created queued running].include?(match.status)
        return redirect_to admin_match_path(match), alert: "Only created, queued, or running matches can be cancelled."
      end

      match.transaction do
        RatingService.new(match).rollback!
        cancelled = match.cancel!
        raise ActiveRecord::Rollback unless cancelled

        match.update!(
          result: nil,
          winner_side: nil,
          termination: "cancelled",
          resigned_by_side: nil,
          forfeit_by_side: nil,
          draw_reason: nil,
          finished_at: nil
        )

        AuditLog.log!(actor: current_admin, action: "admin.match_cancelled", auditable: match)
      end

      match.reload
      if match.status == "cancelled"
        redirect_to admin_match_path(match), notice: "Match cancelled and ratings rolled back."
      else
        redirect_to admin_match_path(match), alert: "Match could not be cancelled because its status changed."
      end
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
        # Keep finalized record immutable while marking the result invalid for rankings.
        match.update!(status: "invalid")
        AuditLog.log!(actor: current_admin, action: "admin.match_invalidated", auditable: match)
      end
      redirect_to admin_match_path(match), notice: "Match invalidated and ratings rolled back."
    end
  end
end
