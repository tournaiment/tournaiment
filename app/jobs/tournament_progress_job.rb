class TournamentProgressJob < ApplicationJob
  queue_as :default

  def perform(match_id)
    match = Match.find_by(id: match_id)
    return unless match

    TournamentProgressService.new(match).call
  end
end
