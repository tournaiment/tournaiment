require "test_helper"

class MatchTest < ActiveSupport::TestCase
  def build_agent(name)
    Agent.create!(name: name)
  end

  test "rated match auto-assigns approved preset when omitted" do
    agent_a = build_agent("MTA1")
    agent_b = build_agent("MTA2")

    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: true,
      time_control: "rapid"
    )

    assert match.time_control_preset.present?
    assert_equal "chess", match.time_control_preset.game_key
    assert_equal true, match.time_control_preset.rated_allowed
    assert_equal "rapid", match.time_control_preset.category
  end

  test "rated match rejects unrated preset" do
    agent_a = build_agent("MTR1")
    agent_b = build_agent("MTR2")
    unrated = TimeControlPreset.create!(
      key: "test_chess_blitz_unrated_match",
      game_key: "chess",
      category: "blitz",
      clock_type: "increment",
      clock_config: { base_seconds: 180, increment_seconds: 0 },
      rated_allowed: false
    )

    match = Match.new(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: true,
      time_control: "blitz",
      time_control_preset: unrated
    )

    assert_not match.valid?
    assert_includes match.errors[:time_control_preset_id], "is not approved for rated games"
  end

  test "rated match requires preset when no approved preset exists for category" do
    agent_a = build_agent("MTP1")
    agent_b = build_agent("MTP2")
    locked_unrated = TimeControlPreset.create!(
      key: "test_chess_rapid_locked_unrated",
      game_key: "chess",
      category: "rapid",
      clock_type: "increment",
      clock_config: { base_seconds: 600, increment_seconds: 0 },
      rated_allowed: false
    )
    tournament = Tournament.create!(
      name: "No Rated Preset Cup",
      status: "running",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true,
      locked_time_control_preset: locked_unrated
    )

    match = Match.new(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: true,
      time_control: "rapid",
      tournament: tournament
    )

    assert_not match.valid?
    assert_includes match.errors[:time_control_preset_id], "is required for rated matches"
  end

  test "stale transition cannot overwrite a newer terminal status" do
    agent_a = build_agent("MTS1")
    agent_b = build_agent("MTS2")

    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: false,
      status: "running"
    )
    stale = Match.find(match.id)

    match.update!(status: "cancelled")
    assert_equal false, stale.finish!
    assert_equal "cancelled", match.reload.status
  end

  test "record_move returns terminal result without persisting while match is running" do
    agent_a = build_agent("MTG1")
    agent_b = build_agent("MTG2")
    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "go",
      rated: false,
      status: "running"
    )

    first = match.record_move!("pass")
    second = match.record_move!("pass")

    assert_nil first[:result]
    assert second[:result].present?
    assert_nil match.reload.result
    assert_equal "running", match.status
  end

  test "record_move persists compatibility move fields required by database" do
    agent_a = build_agent("MTC1")
    agent_b = build_agent("MTC2")
    match = Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      rated: false,
      status: "running"
    )

    data = match.record_move!("e2e4")

    move = match.moves.order(:ply).last
    assert_equal "white", move.actor
    assert_equal "white", move.color
    assert_equal data[:notation], move.notation
    assert_equal data[:notation], move.uci
    assert_equal data[:display], move.display
    assert_equal data[:display], move.san
    assert_equal data[:state], move.state
    assert_equal data[:state], move.fen
  end

  test "cancel supports pre-run states and running only" do
    agent_a = build_agent("MTC3")
    agent_b = build_agent("MTC4")

    created = Match.create!(agent_a: agent_a, agent_b: agent_b, game_key: "chess", rated: false, status: "created")
    queued = Match.create!(agent_a: agent_a, agent_b: agent_b, game_key: "chess", rated: false, status: "queued")
    running = Match.create!(agent_a: agent_a, agent_b: agent_b, game_key: "chess", rated: false, status: "running")
    finished = Match.create!(agent_a: agent_a, agent_b: agent_b, game_key: "chess", rated: false, status: "finished")

    assert created.cancel!
    assert queued.cancel!
    assert running.cancel!
    assert_equal "cancelled", created.reload.status
    assert_equal "cancelled", queued.reload.status
    assert_equal "cancelled", running.reload.status

    assert_equal false, finished.cancel!
    assert_equal "finished", finished.reload.status
  end
end
