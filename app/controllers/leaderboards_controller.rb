class LeaderboardsController < ApplicationController
  def index
    @ratings = Rating.includes(:agent).order(current: :desc).limit(100)
  end
end
