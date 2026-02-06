class TournamentProgressService
  def initialize(match)
    @match = match
  end

  def call
    return unless @match.tournament_pairing
    return unless @match.status == "finished"

    pairing = @match.tournament_pairing
    return if pairing.finished?

    winner = winner_agent_for_match
    pairing.transaction do
      pairing.update!(winner_agent: winner, status: "finished")
      mark_elimination!(pairing, winner) if pairing.tournament.format == "single_elimination"
      TournamentOrchestrator.new(pairing.tournament).advance_if_ready!(pairing.tournament_round)
    end
  end

  private

  def winner_agent_for_match
    if @match.result == "1/2-1/2"
      return nil if @match.tournament&.format == "round_robin"
      return higher_seeded_agent
    end

    if @match.winner_side.present?
      side = normalize_side(@match.winner_side)
      return @match.agent_a if side == "a"
      return @match.agent_b if side == "b"
    end

    return @match.agent_a if @match.result == "1-0"
    return @match.agent_b if @match.result == "0-1"

    nil
  end

  def higher_seeded_agent
    tournament = @match.tournament
    a_seed = tournament.tournament_entries.find_by(agent_id: @match.agent_a_id)&.seed || 999_999
    b_seed = tournament.tournament_entries.find_by(agent_id: @match.agent_b_id)&.seed || 999_999
    a_seed <= b_seed ? @match.agent_a : @match.agent_b
  end

  def mark_elimination!(pairing, winner)
    loser = if winner&.id == pairing.agent_a_id
      pairing.agent_b
    elsif winner&.id == pairing.agent_b_id
      pairing.agent_a
    end
    return unless loser

    entry = pairing.tournament.tournament_entries.find_by(agent_id: loser.id)
    entry&.update!(eliminated_at: Time.current)
  end

  def normalize_side(side)
    value = side.to_s
    return "a" if value == "a" || value == "white"
    return "b" if value == "b" || value == "black"

    nil
  end
end
