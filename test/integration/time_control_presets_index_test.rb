require "test_helper"

class TimeControlPresetsIndexTest < ActionDispatch::IntegrationTest
  test "filters by game and rated" do
    chess_rated = TimeControlPreset.create!(
      key: "tc_chess_rated_1",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true,
      active: true
    )
    TimeControlPreset.create!(
      key: "tc_chess_unrated_1",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 120, increment_seconds: 1 },
      rated_allowed: false,
      active: true
    )
    TimeControlPreset.create!(
      key: "tc_go_rated_1",
      game_key: "go",
      category: "rapid",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
      rated_allowed: true,
      active: true
    )

    get "/time_control_presets", params: { game_key: "chess", rated: true }
    assert_response :ok
    body = JSON.parse(response.body)
    keys = body.map { |row| row["key"] }
    assert_includes keys, chess_rated.key
    body.each do |row|
      assert_equal "chess", row["game_key"]
      assert_equal true, row["rated_allowed"]
    end
  end

  test "filters by tournament allowlist and locked preset" do
    allowed = TimeControlPreset.create!(
      key: "tc_tournament_allowed_1",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true,
      active: true
    )
    other = TimeControlPreset.create!(
      key: "tc_tournament_other_1",
      game_key: "chess",
      category: "rapid",
      clock_type: "increment",
      clock_config: { base_seconds: 600, increment_seconds: 0 },
      rated_allowed: true,
      active: true
    )
    tournament = Tournament.create!(
      name: "Scoped Cup",
      status: "running",
      time_control: "rapid",
      format: "single_elimination",
      game_key: "chess",
      rated: true
    )
    TournamentTimeControlPreset.create!(tournament: tournament, time_control_preset: allowed)

    get "/time_control_presets", params: { tournament_id: tournament.id }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [ allowed.key ], body.map { |row| row["key"] }

    tournament.update!(locked_time_control_preset: other)
    get "/time_control_presets", params: { tournament_id: tournament.id }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [ other.key ], body.map { |row| row["key"] }
  end
end
