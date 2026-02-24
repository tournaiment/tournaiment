require "test_helper"
require_relative "../support/assistant_compatibility/registry"

class AssistantCompatibilityMatrixTest < ActiveSupport::TestCase
  def create_agent(name:, adapter:)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: adapter.metadata)
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    agent
  end

  def build_match(agent_a:, agent_b:, preset_key: "test_chess_rapid_10p0", rated: false)
    preset = TimeControlPreset.find_by!(key: preset_key)
    Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: "chess",
      status: "queued",
      rated: rated,
      time_control: preset.category,
      time_control_preset: preset
    )
  end

  def with_env(env)
    original = {}
    env.each do |key, value|
      original[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end

  test "deterministic adapter matrix covers smoke, signature, and timeout scenarios" do
    run_smoke_scenario!(adapter: AssistantCompatibility::Registry.new.deterministic_adapter, timeout_seconds: "2.0")
    run_signed_scenario!
    run_timeout_scenario!
  end

  test "configured external assistant adapters pass smoke scenario" do
    adapters = AssistantCompatibility::Registry.new.external_adapters
    skip "Set OPENCLAW_TEST_MOVE_ENDPOINT and/or NANOCLAW_TEST_MOVE_ENDPOINT to run this matrix." if adapters.empty?

    adapters.each do |adapter|
      run_smoke_scenario!(adapter: adapter, timeout_seconds: ENV.fetch("ASSISTANT_COMPAT_TIMEOUT_SECONDS", "15.0"))
    end
  end

  private

  def unique_agent_name(prefix)
    token = SecureRandom.hex(3)
    base = "#{prefix}#{token}"
    base[0, 20]
  end

  def run_smoke_scenario!(adapter:, timeout_seconds:)
    adapter.start!
    adapter.script!([ { move: "e2e4" } ]) if adapter.respond_to?(:script!)

    opponent = AssistantCompatibility::Adapters::MockAdapter.new(name: "#{adapter.name}-opp")
    opponent.start!
    opponent.script!([ { move: "resign" } ])

    white = create_agent(name: unique_agent_name("smk#{adapter.name[0, 4]}"), adapter: adapter)
    black = create_agent(name: unique_agent_name("smkopp"), adapter: opponent)
    match = build_match(agent_a: white, agent_b: black)

    with_env("AGENT_MOVE_TIMEOUT_SECONDS" => timeout_seconds.to_s) do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status, "smoke scenario failed for #{adapter.name}"
    assert_equal "resign", match.termination, "expected #{adapter.name} smoke scenario to end by opponent resignation"
    assert_equal "1-0", match.result, "expected #{adapter.name} to produce at least one legal opening move"
  ensure
    opponent&.stop!
    adapter.stop!
  end

  def run_signed_scenario!
    adapter = AssistantCompatibility::Adapters::MockAdapter.new(
      name: "signed-mock",
      move_secret: "compat-secret",
      verify_signature: true
    )
    adapter.start!
    adapter.script!([ { move: "e2e4" } ])

    opponent = AssistantCompatibility::Adapters::MockAdapter.new(name: "signed-opponent")
    opponent.start!
    opponent.script!([ { move: "resign" } ])

    white = create_agent(name: unique_agent_name("sig"), adapter: adapter)
    black = create_agent(name: unique_agent_name("sigopp"), adapter: opponent)
    match = build_match(agent_a: white, agent_b: black)

    with_env("AGENT_MOVE_TIMEOUT_SECONDS" => "2.0") do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    first_request = adapter.requests.first
    assert first_request, "expected signed adapter to receive at least one request"
    assert first_request.headers["x-tournaiment-request-id"].present?
    assert first_request.headers["x-tournaiment-signature"].present?
  ensure
    opponent&.stop!
    adapter&.stop!
  end

  def run_timeout_scenario!
    adapter = AssistantCompatibility::Adapters::MockAdapter.new(name: "timeout-mock")
    adapter.start!
    adapter.script!([ { move: "e2e4", delay_seconds: 0.2 } ])

    opponent = AssistantCompatibility::Adapters::MockAdapter.new(name: "timeout-opponent")
    opponent.start!
    opponent.script!([ { move: "resign" } ])

    white = create_agent(name: unique_agent_name("tout"), adapter: adapter)
    black = create_agent(name: unique_agent_name("toutopp"), adapter: opponent)
    match = build_match(agent_a: white, agent_b: black)

    with_env("AGENT_MOVE_TIMEOUT_SECONDS" => "0.05") do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    assert_equal "no_response", match.termination
    assert_equal "a", match.forfeit_by_side
    assert_equal "0-1", match.result
  ensure
    opponent&.stop!
    adapter&.stop!
  end
end
