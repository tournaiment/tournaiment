class AdminTournamentLifecycleService
  def initialize(tournament:, admin:)
    @tournament = tournament
    @admin = admin
  end

  def cancel!
    affected = 0

    Tournament.transaction do
      @tournament.matches.find_each do |match|
        next if %w[cancelled invalid].include?(match.status)

        rollback_rating!(match)
        if match.status == "finished"
          mark_finished_match!(match, status: "cancelled")
        else
          reset_match_to_cancelled!(match)
        end
        affected += 1
      end

      @tournament.update!(status: "cancelled", ends_at: Time.current)
      AuditLog.log!(
        actor: @admin,
        action: "admin.tournament_cancelled",
        auditable: @tournament,
        metadata: { matches_affected: affected }
      )
    end
  end

  def invalidate!
    affected = 0

    Tournament.transaction do
      @tournament.matches.find_each do |match|
        next if match.status == "invalid"

        rollback_rating!(match)

        if match.status == "finished"
          mark_finished_match!(match, status: "invalid")
          affected += 1
        elsif match.status != "cancelled"
          reset_match_to_cancelled!(match, termination: "tournament_invalidated")
          affected += 1
        end
      end

      @tournament.update!(status: "invalid", ends_at: Time.current)
      AuditLog.log!(
        actor: @admin,
        action: "admin.tournament_invalidated",
        auditable: @tournament,
        metadata: { matches_affected: affected }
      )
    end
  end

  private

  def rollback_rating!(match)
    RatingService.new(match).rollback!
  end

  def reset_match_to_cancelled!(match, termination: "tournament_cancelled")
    match.update!(
      status: "cancelled",
      result: nil,
      winner_side: nil,
      termination: termination,
      resigned_by_side: nil,
      forfeit_by_side: nil,
      draw_reason: nil
    )
    match.moves.delete_all
    match.update!(
      pgn: nil,
      ply_count: 0,
      current_state: match.initial_state,
      finished_at: nil,
      clock_state: {}
    )
  end

  def mark_finished_match!(match, status:)
    # Preserve finalized match record while excluding it from standings/ratings.
    match.update!(status: status)
  end
end
