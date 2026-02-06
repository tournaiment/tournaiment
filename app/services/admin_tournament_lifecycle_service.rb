class AdminTournamentLifecycleService
  def initialize(tournament:, admin:)
    @tournament = tournament
    @admin = admin
  end

  def cancel!
    affected = 0

    Tournament.transaction do
      @tournament.matches.find_each do |match|
        if match.status == "finished"
          rollback_rating!(match)
          mark_finished_match!(match, status: "invalid")
          affected += 1
        elsif %w[created queued running].include?(match.status)
          rollback_rating!(match)
          affected += 1 if reset_match_to_cancelled!(match)
        end
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

        if match.status == "finished"
          rollback_rating!(match)
          mark_finished_match!(match, status: "invalid")
          affected += 1
        elsif %w[created queued running].include?(match.status)
          rollback_rating!(match)
          affected += 1 if reset_match_to_cancelled!(match, termination: "tournament_invalidated")
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
    return false unless match.cancel!

    match.update!(
      result: nil,
      winner_side: nil,
      termination: termination,
      resigned_by_side: nil,
      forfeit_by_side: nil,
      draw_reason: nil,
      finished_at: nil
    )

    true
  end

  def mark_finished_match!(match, status:)
    # Preserve finalized match record while excluding it from standings/ratings.
    match.update!(status: status)
  end
end
