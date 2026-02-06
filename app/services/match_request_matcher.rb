class MatchRequestMatcher
  def initialize(request)
    @request = request
  end

  def process!
    return @request unless @request.open?

    case @request.request_type
    when "challenge"
      match_challenge!
    when "ladder", "tournament"
      match_from_pool!
    else
      @request
    end
  end

  private

  def match_challenge!
    opponent = @request.opponent_agent
    return @request if opponent.nil?
    return @request if @request.requester_agent_id == opponent.id
    return @request if tournament_blocked?(@request.requester_agent, opponent)

    MatchRequest.transaction do
      @request.lock!
      return @request unless @request.open?

      match = create_match!(@request.requester_agent, opponent)
      mark_matched!(@request, match)
    end

    @request.reload
  end

  def match_from_pool!
    candidate = candidate_request
    return @request unless candidate
    return @request if tournament_blocked?(@request.requester_agent, candidate.requester_agent)

    match = nil

    MatchRequest.transaction do
      request_id, candidate_id = [ @request.id, candidate.id ].sort
      locked = MatchRequest.lock.where(id: [ request_id, candidate_id ]).index_by(&:id)
      request = locked.fetch(request_id)
      candidate_request = locked.fetch(candidate_id)
      return @request unless request.open? && candidate_request.open?

      # Preserve requester order to keep actor assignment deterministic.
      first, second = if request.created_at < candidate_request.created_at
                        [ request, candidate_request ]
      elsif request.created_at > candidate_request.created_at
                        [ candidate_request, request ]
      else
                        request.id < candidate_request.id ? [ request, candidate_request ] : [ candidate_request, request ]
      end

      match = create_match!(first.requester_agent, second.requester_agent)
      mark_matched!(request, match)
      mark_matched!(candidate_request, match)
    end

    @request.reload
  end

  def create_match!(agent_a, agent_b)
    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      rated: @request.rated,
      time_control: @request.time_control_preset.category,
      time_control_preset: @request.time_control_preset,
      game_key: @request.game_key,
      game_config: @request.game_config,
      tournament_id: @request.tournament_id
    )
    match.queue! if match.queueable?
    match
  end

  def mark_matched!(request, match)
    request.update!(status: "matched", match: match, matched_at: Time.current)
  end

  def candidate_request
    MatchRequest.open_requests
      .where(request_type: @request.request_type)
      .where(game_key: @request.game_key, rated: @request.rated, time_control_preset_id: @request.time_control_preset_id, tournament_id: @request.tournament_id)
      .where.not(requester_agent_id: @request.requester_agent_id)
      .where.not(id: @request.id)
      .order(:created_at, :id)
      .first
  end

  def tournament_blocked?(agent_a, agent_b)
    return false if @request.tournament_id.blank?

    TournamentEntry.find_by(tournament_id: @request.tournament_id, agent_id: agent_a.id, status: "registered").nil? ||
      TournamentEntry.find_by(tournament_id: @request.tournament_id, agent_id: agent_b.id, status: "registered").nil?
  end
end
