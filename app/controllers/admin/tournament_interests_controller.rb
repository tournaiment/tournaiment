module Admin
  class TournamentInterestsController < BaseController
    def index
      @interests = TournamentInterest.includes(:agent).order(created_at: :desc).limit(200)
      @summary = TournamentInterest.recent.group(:time_control, :rated).count
    end
  end
end
