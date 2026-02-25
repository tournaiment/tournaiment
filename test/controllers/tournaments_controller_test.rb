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

  test "show accepts legacy uuid url params" do
    tournament = Tournament.create!(
      name: "Legacy Param Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )

    get tournament_path(tournament.id)
    assert_response :success
  end

  test "show renders starts and ends with local-time tags" do
    starts_at = Time.utc(2026, 3, 1, 9, 15, 0)
    ends_at = Time.utc(2026, 3, 2, 18, 45, 0)
    tournament = Tournament.create!(
      name: "Time Display Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess",
      starts_at: starts_at,
      ends_at: ends_at
    )

    get tournament_path(tournament)
    assert_response :success
    assert_match "data-controller=\"local-time\"", @response.body
    assert_match starts_at.iso8601, @response.body
    assert_match ends_at.iso8601, @response.body
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

  test "index json includes monied flag and timezone" do
    Tournament.create!(
      name: "Monied API Cup",
      status: "registration_open",
      time_control: "rapid",
      time_zone: "Asia/Singapore",
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
    assert_equal "Asia/Singapore", payload["time_zone"]
  end

  test "index html title-cases table attributes" do
    Tournament.create!(
      name: "Styled Cup",
      status: "registration_open",
      time_control: "rapid",
      rated: true,
      monied: false,
      format: "round_robin",
      game_key: "go"
    )

    get tournaments_path
    assert_response :success
    assert_match "Go", response.body
    assert_match "Round Robin", response.body
    assert_match "Registration Open", response.body
    assert_match "Rapid", response.body
  end
end
