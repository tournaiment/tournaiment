class TournamentOrchestrator
  class Error < StandardError; end

  def initialize(tournament)
    @tournament = tournament
  end

  def start!
    raise Error, "Tournament registration is not open" unless @tournament.registration_open?

    entries = TournamentSeedingService.new(@tournament).call
    raise Error, "At least 2 registered agents are required" if entries.size < 2

    case @tournament.format
    when "single_elimination"
      start_single_elimination!(entries)
    when "round_robin"
      start_round_robin!(entries)
    else
      raise Error, "Tournament format not supported"
    end
  end

  def advance_if_ready!(round)
    return unless round.tournament_id == @tournament.id
    return unless round.tournament_pairings.where.not(status: "finished").none?

    round.update!(status: "finished", finished_at: Time.current)

    if @tournament.format == "round_robin"
      next_round = @tournament.tournament_rounds.where("round_number > ?", round.round_number).order(:round_number).first
      if next_round
        start_round!(next_round)
        AuditLog.log!(
          actor: nil,
          action: "tournament.round_started",
          auditable: @tournament,
          metadata: { round: next_round.round_number }
        )
      else
        finish_tournament!
      end
      return
    end

    winners = round.tournament_pairings.order(:slot).map(&:winner_agent).compact
    if winners.size == 1
      finish_tournament!(winner: winners.first)
      return
    end

    next_round = @tournament.tournament_rounds.create!(
      round_number: round.round_number + 1,
      status: "running",
      started_at: Time.current
    )
    create_pairings_for_round!(next_round, winners)

    AuditLog.log!(
      actor: nil,
      action: "tournament.round_started",
      auditable: @tournament,
      metadata: { round: next_round.round_number }
    )
  end

  private

  def start_single_elimination!(entries)
    Tournament.transaction do
      @tournament.update!(status: "running", starts_at: Time.current)
      round = @tournament.tournament_rounds.create!(round_number: 1, status: "running", started_at: Time.current)
      create_pairings_for_round!(round, entries)
      AuditLog.log!(actor: nil, action: "tournament.started", auditable: @tournament, metadata: { round: 1 })
      notify_registered_agents!("tournament_started", round: 1)
    end
  end

  def start_round_robin!(entries)
    rounds = TournamentRoundRobinSchedulerService.new(entries.map(&:agent)).call

    Tournament.transaction do
      @tournament.update!(status: "running", starts_at: Time.current)

      rounds.each do |scheduled_round|
        round = @tournament.tournament_rounds.create!(
          round_number: scheduled_round.round_number,
          status: scheduled_round.round_number == 1 ? "running" : "pending",
          started_at: (scheduled_round.round_number == 1 ? Time.current : nil)
        )

        scheduled_round.pairings.each_with_index do |pairing, idx|
          create_pairing_with_match!(
            round: round,
            slot: idx + 1,
            agent_a: pairing.agent_a,
            agent_b: pairing.agent_b,
            queue_now: scheduled_round.round_number == 1
          )
        end
      end

      AuditLog.log!(actor: nil, action: "tournament.started", auditable: @tournament, metadata: { round: 1 })
      notify_registered_agents!("tournament_started", round: 1)
    end
  end

  def create_pairings_for_round!(round, entrants)
    seeded_agents = entrants.map { |entry| entry.respond_to?(:agent) ? entry.agent : entry }
    seeded_agents.each_slice(2).with_index(1) do |pair, slot|
      agent_a = pair[0]
      agent_b = pair[1]

      pairing = round.tournament_pairings.create!(
        tournament: @tournament,
        slot: slot,
        agent_a: agent_a,
        agent_b: agent_b,
        status: "pending",
        bye: agent_b.nil?
      )

      if agent_b.nil?
        pairing.update!(winner_agent: agent_a, status: "finished")
      else
        create_match_for_pairing!(pairing, queue_now: true)
      end
    end
  end

  def create_pairing_with_match!(round:, slot:, agent_a:, agent_b:, queue_now:)
    pairing = round.tournament_pairings.create!(
      tournament: @tournament,
      slot: slot,
      agent_a: agent_a,
      agent_b: agent_b,
      status: "pending",
      bye: false
    )
    create_match_for_pairing!(pairing, queue_now: queue_now)
  end

  def create_match_for_pairing!(pairing, queue_now:)
    match = Match.create!(
      tournament: @tournament,
      tournament_pairing: pairing,
      game_key: @tournament.game_key,
      rated: @tournament.rated,
      time_control: @tournament.time_control,
      agent_a: pairing.agent_a,
      agent_b: pairing.agent_b
    )
    if queue_now
      match.queue!
      pairing.update!(status: "running")
      notify_agents_for_pairing_match!(pairing, match)
    end
  end

  def start_round!(round)
    round.update!(status: "running", started_at: Time.current)
    round.tournament_pairings.includes(:match).find_each do |pairing|
      next if pairing.match.nil?
      next unless pairing.match.status == "created"

      pairing.match.queue!
      pairing.update!(status: "running")
      notify_agents_for_pairing_match!(pairing, pairing.match)
    end
  end

  def finish_tournament!(winner: nil)
    @tournament.update!(status: "finished", ends_at: Time.current)
    AuditLog.log!(
      actor: nil,
      action: "tournament.finished",
      auditable: @tournament,
      metadata: { winner_agent_id: winner&.id }
    )
    notify_registered_agents!("tournament_finished", winner_agent_id: winner&.id)
  end

  def notify_registered_agents!(event, payload = {})
    agent_ids = @tournament.tournament_entries.registered.pluck(:agent_id)
    TournamentNotifyAgentsJob.perform_later(
      tournament_id: @tournament.id,
      event: event,
      agent_ids: agent_ids,
      payload: payload
    )
  end

  def notify_agents_for_pairing_match!(pairing, match)
    agent_ids = [ pairing.agent_a_id, pairing.agent_b_id ].compact
    TournamentNotifyAgentsJob.perform_later(
      tournament_id: @tournament.id,
      event: "match_assigned",
      agent_ids: agent_ids,
      payload: {
        round_number: pairing.tournament_round.round_number,
        match_id: match.id,
        tournament_pairing_id: pairing.id
      }
    )
  end
end
