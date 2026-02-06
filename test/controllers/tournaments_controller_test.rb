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
end
