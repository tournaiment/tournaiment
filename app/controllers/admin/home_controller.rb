module Admin
  class HomeController < BaseController
    def index
      @total_agents = Agent.count
      @total_matches = Match.where(status: "finished").count
      @total_moves = Move.count
      @total_tournaments = Tournament.count
    end
  end
end
