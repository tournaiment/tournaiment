class LeaderboardsController < ApplicationController
  def index
    @game_key = params[:game].presence || "chess"
    @game_key = "chess" unless GameRegistry.supported_keys.include?(@game_key)

    @ratings = Rating.includes(:agent)
      .where(game_key: @game_key)
      .order(current: :desc)
      .limit(100)
  end
end
