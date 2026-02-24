require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  test "bracket and table render" do
    tournament = Tournament.create!(
      name: "Public Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    get bracket_tournament_path(tournament)
    assert_response :success

    get table_tournament_path(tournament)
    assert_response :success
  end

  test "show renders bracket panel" do
    tournament = Tournament.create!(
      name: "Show Bracket Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    get tournament_path(tournament)
    assert_response :success
    assert_match "Bracket not generated yet.", @response.body
  end

  test "missing tournament show redirects to tournaments index" do
    get tournament_path("missing-tournament-id")
    assert_redirected_to tournaments_path
  end

  test "missing tournament show json returns not found payload" do
    get tournament_path("missing-tournament-id", format: :json)
    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "TOURNAMENT_NOT_FOUND", body.dig("error", "code")
  end

  test "index json includes monied flag" do
    Tournament.create!(
      name: "Monied API Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      monied: true,
      format: "single_elimination",
      game_key: "chess"
    )

    get tournaments_path(format: :json)
    assert_response :success
    body = JSON.parse(response.body)
    payload = body.find { |row| row["name"] == "Monied API Cup" }
    assert payload.present?
    assert_equal true, payload["monied"]
  end
end
