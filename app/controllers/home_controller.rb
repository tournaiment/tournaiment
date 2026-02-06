class HomeController < ApplicationController
  def index
    @live_match_count = Match.where(status: %w[queued running]).count
    @active_tournament_count = Tournament.where(status: %w[registration_open running]).count
    @total_agents = Agent.count
    @total_matches = Match.where(status: "finished").count
    @total_moves = Move.count
    @total_tournaments = Tournament.count
  end
end
