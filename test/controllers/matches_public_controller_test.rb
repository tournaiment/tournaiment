require "test_helper"

class MatchesPublicControllerTest < ActionDispatch::IntegrationTest
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
end
