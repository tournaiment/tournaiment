require "test_helper"

class RatingServiceTest < ActiveSupport::TestCase
  def create_finished_match(agent_a:, agent_b:, game_key:, preset:, result:, winner_side:, finished_at: Time.current)
    Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: game_key,
      rated: true,
      time_control: preset.category,
      time_control_preset: preset,
      status: "finished",
      result: result,
      winner_side: winner_side,
      termination: "checkmate",
      finished_at: finished_at
    )
  end

  test "pair limit allows the 10th rated match in 24 hours" do
    agent_a = Agent.create!(name: "RPA1")
    agent_b = Agent.create!(name: "RPB1")
    preset = TimeControlPreset.find_by!(key: "test_chess_rapid_10p0")

    9.times do
      create_finished_match(
        agent_a: agent_a,
        agent_b: agent_b,
        game_key: "chess",
        preset: preset,
        result: "1-0",
        winner_side: "a",
        finished_at: 1.hour.ago
      )
    end

    target = create_finished_match(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      preset: preset,
      result: "1-0",
      winner_side: "a",
      finished_at: Time.current
    )

    RatingService.new(target).apply!

    assert_equal 2, RatingChange.where(match_id: target.id).count
  end

  test "pair limit blocks the 11th rated match in 24 hours" do
    agent_a = Agent.create!(name: "RPA2")
    agent_b = Agent.create!(name: "RPB2")
    preset = TimeControlPreset.find_by!(key: "test_chess_rapid_10p0")

    10.times do
      create_finished_match(
        agent_a: agent_a,
        agent_b: agent_b,
        game_key: "chess",
        preset: preset,
        result: "1-0",
        winner_side: "a",
        finished_at: 1.hour.ago
      )
    end

    target = create_finished_match(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      preset: preset,
      result: "1-0",
      winner_side: "a",
      finished_at: Time.current
    )

    RatingService.new(target).apply!

    assert_equal 0, RatingChange.where(match_id: target.id).count
  end

  test "go ratings map by game actors not side ordering" do
    black_agent = Agent.create!(name: "RGO1")
    white_agent = Agent.create!(name: "RGO2")
    preset = TimeControlPreset.find_by!(key: "test_go_rapid_10m_5x30")
    initial = RatingSystemRegistry.fetch!("go").initial_rating

    black_rating = black_agent.ratings.find_or_create_by!(game_key: "go") { |rating| rating.current = initial }
    white_rating = white_agent.ratings.find_or_create_by!(game_key: "go") { |rating| rating.current = initial }

    match = create_finished_match(
      agent_a: black_agent,
      agent_b: white_agent,
      game_key: "go",
      preset: preset,
      result: "0-1",
      winner_side: "a",
      finished_at: Time.current
    )

    RatingService.new(match).apply!

    assert_operator black_rating.reload.current, :>, initial
    assert_operator white_rating.reload.current, :<, initial
  end
end
