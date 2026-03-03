require "test_helper"

class MatchesPublicControllerTest < ActionDispatch::IntegrationTest
  def create_agent(name)
    operator, = create_operator_account(email: "#{name.downcase}@example.test")
    agent, = create_agent_for_operator(operator_account: operator, name: name)
    agent
  end

  test "show redirects to matches list when match is missing" do
    get public_match_path(SecureRandom.uuid)

    assert_redirected_to public_matches_path
  end

  test "show returns not found json when match is missing" do
    get public_match_path(SecureRandom.uuid), as: :json

    assert_response :not_found
    payload = JSON.parse(response.body)
    assert_equal "Match not found.", payload["error"]
  end

  test "index paginates results" do
    agent_a = create_agent("MatchPageA")
    agent_b = create_agent("MatchPageB")
    60.times do |idx|
      created_at = Time.current - idx.minutes
      Match.create!(
        agent_a: agent_a,
        agent_b: agent_b,
        game_key: "chess",
        rated: false,
        status: "finished",
        result: "1-0",
        winner_side: "a",
        termination: "checkmate",
        created_at: created_at,
        updated_at: created_at
      )
    end

    newest_hidden_on_page_one = Match.order(created_at: :desc).offset(30).first

    get public_matches_path
    assert_response :success
    assert_match "Page 1 of 2", response.body
    refute_match newest_hidden_on_page_one.id, response.body

    get public_matches_path(page: 2)
    assert_response :success
    assert_match "Page 2 of 2", response.body
    assert_match newest_hidden_on_page_one.id, response.body
  end
end
