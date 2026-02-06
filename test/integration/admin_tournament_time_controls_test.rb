require "test_helper"

class AdminTournamentTimeControlsTest < ActionDispatch::IntegrationTest
  def create_admin
    AdminUser.create!(email: "admin_tc@example.com", password: "password123", password_confirmation: "password123")
  end

  test "admin can set allowed and locked presets within tournament constraints" do
    admin = create_admin
    post "/admin/login", params: { email: admin.email, password: "password123" }
    assert_response :redirect

    allowed = TimeControlPreset.create!(
      key: "admin_tc_allowed_1",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 2 },
      rated_allowed: true,
      active: true
    )
    blocked_game = TimeControlPreset.create!(
      key: "admin_tc_blocked_game_1",
      game_key: "go",
      category: "rapid",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
      rated_allowed: true,
      active: true
    )
    tournament = Tournament.create!(
      name: "Admin TC Cup",
      status: "running",
      time_control: "rapid",
      format: "single_elimination",
      game_key: "chess",
      rated: true
    )

    patch "/admin/tournaments/#{tournament.id}/time_controls", params: {
      allowed_time_control_preset_ids: [ allowed.id, blocked_game.id ],
      locked_time_control_preset_id: allowed.id
    }
    assert_response :redirect
    tournament.reload
    assert_nil tournament.locked_time_control_preset_id
    assert_empty tournament.allowed_time_control_presets

    patch "/admin/tournaments/#{tournament.id}/time_controls", params: {
      allowed_time_control_preset_ids: [ allowed.id ],
      locked_time_control_preset_id: allowed.id
    }
    assert_response :redirect
    tournament.reload
    assert_equal allowed.id, tournament.locked_time_control_preset_id
    assert_equal [ allowed.id ], tournament.allowed_time_control_presets.pluck(:id)
  end

  test "admin can create tournament with preset rules from form params" do
    admin = create_admin
    post "/admin/login", params: { email: admin.email, password: "password123" }
    assert_response :redirect

    preset = TimeControlPreset.create!(
      key: "admin_tc_create_1",
      game_key: "go",
      category: "rapid",
      clock_type: "byoyomi",
      clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
      rated_allowed: true,
      active: true
    )

    post "/admin/tournaments", params: {
      tournament: {
        name: "Create With Presets",
        status: "registration_open",
        format: "single_elimination",
        game_key: "go",
        time_control: "rapid",
        rated: true
      },
      allowed_time_control_preset_ids: [ preset.id ],
      locked_time_control_preset_id: preset.id
    }
    assert_response :redirect

    tournament = Tournament.find_by!(name: "Create With Presets")
    assert_equal preset.id, tournament.locked_time_control_preset_id
    assert_equal [ preset.id ], tournament.allowed_time_control_presets.pluck(:id)
  end

  test "admin update rejects invalid preset for changed game" do
    admin = create_admin
    post "/admin/login", params: { email: admin.email, password: "password123" }
    assert_response :redirect

    chess_preset = TimeControlPreset.create!(
      key: "admin_tc_update_chess_1",
      game_key: "chess",
      category: "rapid",
      clock_type: "increment",
      clock_config: { base_seconds: 600, increment_seconds: 0 },
      rated_allowed: true,
      active: true
    )
    tournament = Tournament.create!(
      name: "Update Presets",
      status: "registration_open",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true
    )

    patch "/admin/tournaments/#{tournament.id}", params: {
      tournament: {
        name: tournament.name,
        status: tournament.status,
        format: tournament.format,
        game_key: "go",
        time_control: tournament.time_control,
        rated: tournament.rated
      },
      allowed_time_control_preset_ids: [ chess_preset.id ],
      locked_time_control_preset_id: chess_preset.id
    }
    assert_response :unprocessable_entity

    tournament.reload
    assert_equal "chess", tournament.game_key
    assert_nil tournament.locked_time_control_preset_id
  end
end
