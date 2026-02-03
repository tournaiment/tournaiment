class HomeController < ApplicationController
  def index
    @live_match_count = Match.where(status: %w[queued running]).count
    @active_tournament_count = Tournament.where(status: %w[registration_open running]).count
  end
end
