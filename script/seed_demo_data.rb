#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

module DemoSeed
  AGENT_NAMES = [
    "NeonRook",
    "QuantumBishop",
    "CipherKnight",
    "PlasmaQueen",
    "VoidPawn",
    "SignalLancer",
    "VectorMonk",
    "ArcStorm",
    "EchoForge",
    "PulseArray",
    "SpecterLine",
    "NovaGrid"
  ].freeze

  OPENINGS = [
    %w[e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6],
    %w[d2d4 d7d5 c2c4 e7e6 b1c3 g8f6],
    %w[c2c4 e7e5 b1c3 g8f6 g2g3 d7d5],
    %w[e2e4 c7c5 g1f3 d7d6 d2d4 c5d4],
    %w[g1f3 d7d5 g2g3 c7c6 f1g2 g8f6]
  ].freeze

  RESULTS = ["1-0", "0-1", "1/2-1/2"].freeze

  TIME_CONTROLS = ["bullet", "blitz", "rapid", "classical"].freeze

  module_function

  def run!
    if ENV["SEED_DEMO_FORCE"] == "1"
      Match.delete_all
      Move.delete_all
      RatingChange.delete_all
      Rating.delete_all
      TournamentEntry.delete_all
      Tournament.delete_all
      TournamentInterest.delete_all
      AuditLog.delete_all
    end

    seed_agents
    seed_matches if Match.count.zero?
  end

  def seed_agents
    AGENT_NAMES.each_with_index do |name, idx|
      agent = Agent.find_or_initialize_by(name: name)
      next unless agent.new_record?

      agent.description = "Demo agent ##{idx + 1}"
      agent.metadata = {
        move_endpoint: "https://example.com/agents/#{name.downcase}/move"
      }
      raw_key = Agent.generate_api_key
      agent.api_key = raw_key
      agent.api_key_hash = Agent.api_key_hash(raw_key)
      agent.api_key_last_rotated_at = Time.current
      agent.save!
      AuditLog.log!(actor: nil, action: "agent.seeded", auditable: agent)
    end
  end

  def seed_matches
    agents = Agent.order(:created_at).limit(AGENT_NAMES.length).to_a
    return if agents.length < 2

    12.times do |i|
      white = agents.sample
      black = (agents - [white]).sample

      match = Match.create!(
        white_agent: white,
        black_agent: black,
        rated: true,
        time_control: TIME_CONTROLS.sample,
        status: "running",
        game_key: "chess"
      )

      apply_opening(match, OPENINGS.sample)

      if i < 9
        finalize_match(match, RESULTS.sample)
      else
        match.update!(status: "running", started_at: match.started_at || Time.current)
      end
    end
  end

  def apply_opening(match, moves)
    state = match.initial_state
    moves.each_with_index do |uci, idx|
      actor = ChessRules.actor_for_ply(idx)
      data = ChessRules.apply_move(state: state, move: uci, actor: actor)
      state = data[:state]
      ply = idx + 1
      move_number = ChessRules.turn_number_for_ply(ply)

      Move.create!(
        match: match,
        ply: ply,
        move_number: move_number,
        actor: actor,
        notation: uci,
        display: data[:display],
        state: data[:state],
        color: actor,
        uci: uci,
        san: data[:display],
        fen: data[:state]
      )
    end

    match.update!(
      current_state: state,
      current_fen: state,
      ply_count: moves.length,
      started_at: match.started_at || Time.current
    )
  end

  def finalize_match(match, result)
    rules = GameRegistry.fetch!(match.game_key)
    termination = rules.termination_for_result(result)
    scores = rules.scores_for_result(result)
    winner_actor = if scores["white"] > scores["black"]
                     "white"
                   elsif scores["black"] > scores["white"]
                     "black"
                   else
                     nil
                   end

    match.update!(
      status: "finished",
      result: result,
      termination: termination,
      finished_at: Time.current,
      winner_actor: winner_actor,
      winner_color: winner_actor
    )

    moves = match.moves.order(:ply).pluck(:display)
    match.update!(pgn: rules.render_record(moves: moves, result: result, tags: match.send(:default_tags)))
    RatingService.new(match).apply!
  end
end

DemoSeed.run!
