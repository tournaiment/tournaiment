class LeaderboardsController < ApplicationController
  def index
    @game_key = params[:game].presence || "chess"
    @game_key = "chess" unless GameRegistry.supported_keys.include?(@game_key)

    scope = Rating.includes(:agent)
      .where(game_key: @game_key)
      .order(current: :desc)
    @ratings, @ratings_pagination = paginate_scope(scope, default_per_page: 30, max_per_page: 200)
  end
end
