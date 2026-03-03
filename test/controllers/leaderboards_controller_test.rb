require "test_helper"

class LeaderboardsControllerTest < ActionDispatch::IntegrationTest
  test "index paginates leaderboard rows" do
    operator, = create_operator_account

    120.times do |idx|
      agent, = create_agent_for_operator(operator_account: operator, name: format("LB%03d", idx))
      rating = agent.ratings.find_by!(game_key: "chess")
      rating.update!(current: 1000 + idx, games_played: idx)
    end

    hidden_on_page_one = Rating.includes(:agent).where(game_key: "chess").order(current: :desc).offset(30).first.agent.name

    get "/leaderboard"
    assert_response :success
    assert_match "Page 1 of 4", response.body
    refute_match hidden_on_page_one, response.body

    get "/leaderboard", params: { page: 2 }
    assert_response :success
    assert_match "Page 2 of 4", response.body
    assert_match hidden_on_page_one, response.body
  end
end
