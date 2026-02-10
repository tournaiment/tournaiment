require "test_helper"

module Admin
  class TournamentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = AdminUser.create!(email: "admin-test@tournaiment.local", password: "password123")
      post admin_login_path, params: { email: @admin.email, password: "password123" }
    end

    test "admin can create and update tournament" do
      post admin_tournaments_path, params: {
        tournament: {
          name: "Admin Cup",
          description: "Created in admin",
          status: "registration_open",
          format: "round_robin",
          game_key: "chess",
          time_control: "rapid",
          rated: true,
          monied: true,
          max_players: 8
        }
      }

      tournament = Tournament.find_by!(name: "Admin Cup")
      assert_equal true, tournament.monied
      assert_redirected_to admin_tournament_path(tournament)

      patch admin_tournament_path(tournament), params: {
        tournament: {
          name: "Admin Cup Updated",
          format: "single_elimination",
          monied: false
        }
      }

      tournament.reload
      assert_equal "Admin Cup Updated", tournament.name
      assert_equal "single_elimination", tournament.format
      assert_equal false, tournament.monied
      assert_redirected_to admin_tournament_path(tournament)
    end

    test "admin can cancel tournament and rollback ratings" do
      tournament = Tournament.create!(
        name: "Cancel Cup",
        status: "running",
        format: "single_elimination",
        game_key: "chess",
        time_control: "rapid",
        rated: true
      )
      a1 = Agent.create!(name: "ATC1")
      a2 = Agent.create!(name: "ATC2")
      TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered", seed: 1)
      TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered", seed: 2)
      match = Match.create!(
        tournament: tournament,
        game_key: "chess",
        time_control: "rapid",
        rated: true,
        agent_a: a1,
        agent_b: a2,
        status: "finished",
        result: "1-0",
        winner_side: "a",
        termination: "checkmate",
        pgn: "[Event \"Cancel Cup\"]",
        finished_at: Time.current
      )

      initial_a = a1.ratings.find_by!(game_key: "chess").current
      initial_b = a2.ratings.find_by!(game_key: "chess").current
      RatingService.new(match).apply!
      assert_operator a1.ratings.find_by!(game_key: "chess").current, :>, initial_a

      post cancel_admin_tournament_path(tournament)
      assert_redirected_to admin_tournament_path(tournament)

      tournament.reload
      match.reload
      assert_equal "cancelled", tournament.status
      assert_equal "invalid", match.status
      assert_equal "1-0", match.result
      assert_equal "a", match.winner_side
      assert_equal "checkmate", match.termination
      assert_equal "[Event \"Cancel Cup\"]", match.pgn
      assert_equal 0, RatingChange.where(match_id: match.id).count
      assert_equal initial_a, a1.ratings.find_by!(game_key: "chess").reload.current
      assert_equal initial_b, a2.ratings.find_by!(game_key: "chess").reload.current
    end

    test "admin can invalidate finished tournament and rollback ratings" do
      tournament = Tournament.create!(
        name: "Invalidate Cup",
        status: "finished",
        format: "single_elimination",
        game_key: "chess",
        time_control: "rapid",
        rated: true
      )
      a1 = Agent.create!(name: "ATI1")
      a2 = Agent.create!(name: "ATI2")
      TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered", seed: 1)
      TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered", seed: 2)
      match = Match.create!(
        tournament: tournament,
        game_key: "chess",
        time_control: "rapid",
        rated: true,
        agent_a: a1,
        agent_b: a2,
        status: "finished",
        result: "1-0",
        winner_side: "a",
        termination: "checkmate",
        pgn: "[Event \"Invalidate Cup\"]",
        finished_at: Time.current
      )
      RatingService.new(match).apply!

      post invalidate_admin_tournament_path(tournament)
      assert_redirected_to admin_tournament_path(tournament)

      tournament.reload
      match.reload
      assert_equal "invalid", tournament.status
      assert_equal "invalid", match.status
      assert_equal "1-0", match.result
      assert_equal "a", match.winner_side
      assert_equal "checkmate", match.termination
      assert_equal "[Event \"Invalidate Cup\"]", match.pgn
      assert_equal 0, RatingChange.where(match_id: match.id).count
    end

    test "admin repair health endpoint applies fixes" do
      tournament = Tournament.create!(
        name: "Repair Cup",
        status: "running",
        format: "single_elimination",
        game_key: "chess",
        time_control: "rapid",
        rated: true
      )
      a1 = Agent.create!(name: "ARH1")
      a2 = Agent.create!(name: "ARH2")
      TournamentEntry.create!(tournament: tournament, agent: a1, status: "registered", seed: 1)
      TournamentEntry.create!(tournament: tournament, agent: a2, status: "registered", seed: 2)
      round = tournament.tournament_rounds.create!(round_number: 1, status: "running")
      pairing = tournament.tournament_pairings.create!(
        tournament_round: round,
        tournament: tournament,
        slot: 1,
        agent_a: a1,
        agent_b: a2,
        status: "running",
        bye: false
      )
      Match.create!(
        tournament: tournament,
        tournament_pairing: pairing,
        game_key: "chess",
        time_control: "rapid",
        rated: true,
        agent_a: a1,
        agent_b: a2,
        status: "finished",
        result: "1-0",
        termination: "checkmate",
        finished_at: Time.current
      )

      post repair_health_admin_tournament_path(tournament)
      assert_redirected_to admin_tournament_path(tournament)

      tournament.reload
      pairing.reload
      round.reload
      assert_equal "finished", pairing.status
      assert_equal "finished", round.status
      assert_equal "finished", tournament.status
    end

    test "show includes notification delivery analytics" do
      tournament = Tournament.create!(
        name: "Notify Admin Cup",
        status: "running",
        format: "single_elimination",
        game_key: "chess",
        time_control: "rapid",
        rated: true
      )
      agent = Agent.create!(name: "ATN1")
      AuditLog.log!(
        actor: nil,
        action: "tournament.notified",
        auditable: tournament,
        metadata: { agent_id: agent.id, event: "match_assigned", status: 200 }
      )

      get admin_tournament_path(tournament)
      assert_response :success
      assert_match "Bracket not generated yet.", @response.body
      assert_match "Notification Delivery", @response.body
      assert_match "match_assigned", @response.body
      assert_match agent.name, @response.body
    end
  end
end
