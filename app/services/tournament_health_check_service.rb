class TournamentHealthCheckService
  def initialize(tournament:, actor: nil)
    @tournament = tournament
    @actor = actor
    @issues = []
    @fixes = []
  end

  def report
    reset!
    run_checks(repair: false)
    build_report
  end

  def repair!
    reset!
    Tournament.transaction do
      run_checks(repair: true)
      AuditLog.log!(
        actor: @actor,
        action: "admin.tournament_health_repaired",
        auditable: @tournament,
        metadata: { fixes_applied: @fixes.count, issues_found: @issues.count }
      )
    end
    build_report
  end

  private

  def reset!
    @issues = []
    @fixes = []
  end

  def run_checks(repair:)
    check_pairings(repair: repair)
    check_rounds(repair: repair)
    check_tournament_status(repair: repair)
  end

  def check_pairings(repair:)
    @tournament.tournament_pairings.includes(:match, :tournament_round).find_each do |pairing|
      if pairing.bye?
        next_status = "finished"
        next_winner = pairing.agent_a
      elsif pairing.match.nil?
        add_issue("pairing_missing_match", "Pairing #{pairing.id} has no match")
        next
      else
        next_status = expected_pairing_status_for_match(pairing.match)
        next_winner = expected_winner_for_pairing(pairing)
      end

      if pairing.status != next_status
        add_issue("pairing_status_mismatch", "Pairing #{pairing.id} status #{pairing.status} should be #{next_status}")
        if repair
          pairing.update!(status: next_status)
          add_fix("pairing_status_updated", pairing_id: pairing.id, status: next_status)
        end
      end

      if pairing.status == "finished" && pairing.winner_agent_id != next_winner&.id
        if next_winner.nil? && @tournament.format == "round_robin"
          # Draws in round robin have no winner.
        else
          add_issue("pairing_winner_mismatch", "Pairing #{pairing.id} winner is inconsistent")
          if repair
            pairing.update!(winner_agent: next_winner)
            add_fix("pairing_winner_updated", pairing_id: pairing.id, winner_agent_id: next_winner&.id)
          end
        end
      end
    end
  end

  def check_rounds(repair:)
    @tournament.tournament_rounds.includes(:tournament_pairings).find_each do |round|
      expected = expected_round_status(round)
      if round.status != expected
        add_issue("round_status_mismatch", "Round #{round.round_number} status #{round.status} should be #{expected}")
        if repair
          attrs = { status: expected }
          attrs[:started_at] = Time.current if expected == "running" && round.started_at.nil?
          attrs[:finished_at] = Time.current if expected == "finished" && round.finished_at.nil?
          attrs[:finished_at] = nil if expected != "finished"
          round.update!(attrs)
          add_fix("round_status_updated", round_id: round.id, status: expected)
        end
      end
    end
  end

  def check_tournament_status(repair:)
    expected = expected_tournament_status
    return if expected.nil? || @tournament.status == expected

    add_issue("tournament_status_mismatch", "Tournament status #{@tournament.status} should be #{expected}")
    return unless repair

    attrs = { status: expected }
    attrs[:ends_at] = Time.current if %w[finished cancelled invalid].include?(expected) && @tournament.ends_at.nil?
    attrs[:ends_at] = nil if expected == "running"
    @tournament.update!(attrs)
    add_fix("tournament_status_updated", status: expected)
  end

  def expected_pairing_status_for_match(match)
    return "finished" if %w[finished cancelled invalid failed].include?(match.status)
    return "running" if %w[running queued].include?(match.status)

    "pending"
  end

  def expected_winner_for_pairing(pairing)
    return pairing.agent_a if pairing.bye?

    match = pairing.match
    return pairing.winner_agent if match.nil?
    if match.winner_side.present?
      side = normalize_side(match.winner_side)
      return pairing.agent_a if side == "a"
      return pairing.agent_b if side == "b"
    end
    return pairing.agent_a if match.result == "1-0"
    return pairing.agent_b if match.result == "0-1"

    if match.result == "1/2-1/2" && @tournament.format == "single_elimination"
      a_seed = @tournament.tournament_entries.find_by(agent_id: pairing.agent_a_id)&.seed || 999_999
      b_seed = @tournament.tournament_entries.find_by(agent_id: pairing.agent_b_id)&.seed || 999_999
      return a_seed <= b_seed ? pairing.agent_a : pairing.agent_b
    end

    nil
  end

  def expected_round_status(round)
    statuses = TournamentPairing.where(tournament_round_id: round.id).pluck(:status)
    return "pending" if statuses.empty?
    return "finished" if statuses.all? { |status| status == "finished" }
    return "running" if statuses.any? { |status| status == "running" }

    "pending"
  end

  def expected_tournament_status
    return nil unless %w[running finished].include?(@tournament.status)

    statuses = TournamentRound.where(tournament_id: @tournament.id).pluck(:status)
    return "running" if statuses.empty?
    return "finished" if statuses.all? { |status| status == "finished" }

    "running"
  end

  def add_issue(code, message)
    @issues << { code: code, message: message }
  end

  def add_fix(code, metadata = {})
    @fixes << { code: code, metadata: metadata }
  end

  def build_report
    {
      healthy: @issues.empty?,
      issues: @issues,
      issue_count: @issues.count,
      fixes_applied: @fixes,
      fixes_count: @fixes.count
    }
  end

  def normalize_side(side)
    value = side.to_s
    return "a" if value == "a" || value == "white"
    return "b" if value == "b" || value == "black"

    nil
  end
end
