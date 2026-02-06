require "test_helper"

module Admin
  class MatchesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "admin-matches@tournaiment.local", password: "password123")
      @preset = TimeControlPreset.find_by!(key: "test_chess_rapid_10p0")
      post admin_login_path, params: { email: @admin.email, password: "password123" }
    end

    test "cancel rolls back ratings and clears match outcome state" do
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
      assert_nil match.result
      assert_nil match.winner_side
      assert_nil match.finished_at
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
  end
end
