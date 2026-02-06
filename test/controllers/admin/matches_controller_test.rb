require "test_helper"

module Admin
  class MatchesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "admin-matches@tournaiment.local", password: "password123")
      @preset = TimeControlPreset.find_by!(key: "test_chess_rapid_10p0")
      post admin_login_path, params: { email: @admin.email, password: "password123" }
    end

    test "cancel rolls back ratings while preserving finalized record" do
      agent_a = Agent.create!(name: "AMC1")
      agent_b = Agent.create!(name: "AMC2")
      match = Match.create!(
        game_key: "chess",
        time_control: "rapid",
        time_control_preset: @preset,
        rated: true,
        agent_a: agent_a,
        agent_b: agent_b,
        status: "finished",
        result: "1-0",
        winner_side: "a",
        termination: "checkmate",
        pgn: "[Event \"Tournaiment Match\"]",
        finished_at: Time.current
      )

      initial_a = agent_a.ratings.find_by!(game_key: "chess").current
      initial_b = agent_b.ratings.find_by!(game_key: "chess").current
      RatingService.new(match).apply!
      assert_operator agent_a.ratings.find_by!(game_key: "chess").reload.current, :>, initial_a

      post cancel_admin_match_path(match)
      assert_redirected_to admin_match_path(match)

      match.reload
      assert_equal "cancelled", match.status
      assert_equal "1-0", match.result
      assert_equal "a", match.winner_side
      assert_equal "checkmate", match.termination
      assert_equal "[Event \"Tournaiment Match\"]", match.pgn
      assert_not_nil match.finished_at
      assert_equal 0, RatingChange.where(match_id: match.id).count
      assert_equal initial_a, agent_a.ratings.find_by!(game_key: "chess").reload.current
      assert_equal initial_b, agent_b.ratings.find_by!(game_key: "chess").reload.current
    end

    test "invalidate rejects non-finished matches" do
      agent_a = Agent.create!(name: "AMI1")
      agent_b = Agent.create!(name: "AMI2")
      match = Match.create!(
        game_key: "chess",
        time_control: "rapid",
        time_control_preset: @preset,
        rated: true,
        agent_a: agent_a,
        agent_b: agent_b,
        status: "running"
      )

      post invalidate_admin_match_path(match)
      assert_redirected_to admin_match_path(match)
      assert_equal "running", match.reload.status
    end

    test "invalidate is idempotent for already invalid matches" do
      agent_a = Agent.create!(name: "AMI3")
      agent_b = Agent.create!(name: "AMI4")
      match = Match.create!(
        game_key: "chess",
        time_control: "rapid",
        time_control_preset: @preset,
        rated: true,
        agent_a: agent_a,
        agent_b: agent_b,
        status: "invalid"
      )

      post invalidate_admin_match_path(match)
      assert_redirected_to admin_match_path(match)
      assert_equal "invalid", match.reload.status
    end

    test "invalidate preserves finalized record data" do
      agent_a = Agent.create!(name: "AMI5")
      agent_b = Agent.create!(name: "AMI6")
      match = Match.create!(
        game_key: "chess",
        time_control: "rapid",
        time_control_preset: @preset,
        rated: true,
        agent_a: agent_a,
        agent_b: agent_b,
        status: "finished",
        result: "1-0",
        winner_side: "a",
        termination: "checkmate",
        pgn: "[Event \"Immutable\"]",
        finished_at: Time.current
      )

      post invalidate_admin_match_path(match)
      assert_redirected_to admin_match_path(match)

      match.reload
      assert_equal "invalid", match.status
      assert_equal "1-0", match.result
      assert_equal "a", match.winner_side
      assert_equal "checkmate", match.termination
      assert_equal "[Event \"Immutable\"]", match.pgn
    end
  end
end
