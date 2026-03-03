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

  test "show projects future rounds for active single elimination bracket" do
    tournament = Tournament.create!(
      name: "Projected Bracket Cup",
      status: "running",
      time_control: "rapid",
      rated: true,
      format: "single_elimination",
      game_key: "chess"
    )
    operator, = create_operator_account(plan: PlanEntitlement::PRO)
    agents = 8.times.map do |idx|
      agent, = create_agent_for_operator(operator_account: operator, name: "PB_#{idx}")
      agent
    end
    round = tournament.tournament_rounds.create!(round_number: 1, status: "running")
    4.times do |idx|
      tournament.tournament_pairings.create!(
        tournament_round: round,
        slot: idx + 1,
        status: "running",
        bye: false,
        agent_a: agents[idx * 2],
        agent_b: agents[(idx * 2) + 1]
      )
    end

    get tournament_path(tournament)

    assert_response :success
    assert_match "Semifinal", @response.body
    assert_match "Final", @response.body
    assert_match "TBD", @response.body
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
      time_zone: "Asia/Singapore",
      starts_at: starts_at,
      ends_at: ends_at
    )

    get tournament_path(tournament)
    assert_response :success
    assert_match "data-controller=\"local-time\"", @response.body
    assert_match starts_at.iso8601, @response.body
    assert_match ends_at.iso8601, @response.body
    assert_match "Your time", @response.body
    assert_match "Tournament time", @response.body
    assert_match "+08", @response.body
    assert_match "tournament-schedule-grid", @response.body
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

  test "index html paginates tournament table" do
    31.times do |idx|
      created_at = Time.current - idx.minutes
      Tournament.create!(
        name: format("Paged Cup %02d", idx),
        status: "registration_open",
        time_control: "rapid",
        rated: false,
        monied: false,
        format: "single_elimination",
        game_key: "chess",
        created_at: created_at,
        updated_at: created_at
      )
    end

    hidden_on_page_one = Tournament.order(created_at: :desc).offset(30).first

    get tournaments_path
    assert_response :success
    assert_match "Page 1 of 2", response.body
    refute_match hidden_on_page_one.name, response.body

    get tournaments_path(page: 2)
    assert_response :success
    assert_match "Page 2 of 2", response.body
    assert_match hidden_on_page_one.name, response.body
  end
end
