#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

dry_run = ENV["DRY_RUN"] == "1"

unless dry_run
  puts "This will delete demo agents and related data. Continue? (yes/no)"
  confirm = STDIN.gets&.strip
  unless confirm == "yes"
    puts "Aborted."
    exit(0)
  end
end

demo_names = %w[
  NeonRook
  QuantumBishop
  CipherKnight
  PlasmaQueen
  VoidPawn
  SignalLancer
  VectorMonk
  ArcStorm
  EchoForge
  PulseArray
  SpecterLine
  NovaGrid
].freeze

agent_ids = Agent.where(name: demo_names).pluck(:id)
match_ids = Match.where(white_agent_id: agent_ids)
                 .or(Match.where(black_agent_id: agent_ids))
                 .pluck(:id)

targets = {
  match_agent_models: MatchAgentModel.where(match_id: match_ids),
  moves: Move.where(match_id: match_ids),
  rating_changes: RatingChange.where(match_id: match_ids),
  matches: Match.where(id: match_ids),
  tournament_entries: TournamentEntry.where(agent_id: agent_ids),
  tournament_interests: TournamentInterest.where(agent_id: agent_ids),
  ratings: Rating.where(agent_id: agent_ids),
  agents: Agent.where(id: agent_ids)
}

if dry_run
  targets.each do |label, relation|
    puts "[DRY RUN] #{label}: #{relation.count}"
  end
  exit(0)
end

targets.each_value(&:delete_all)
