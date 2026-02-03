class MatchRunnerJob < ApplicationJob
  queue_as :default

  def perform(match_id)
    match = Match.find(match_id)
    MatchRunner.new(match).run!
  end
end
