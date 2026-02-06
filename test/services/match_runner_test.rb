require "test_helper"

class MatchRunnerTest < ActiveSupport::TestCase
  def create_agent(name)
    token = Agent.generate_api_key
    agent = Agent.new(name: name, metadata: { "move_endpoint" => "https://agent.example.com/move" })
    agent.api_key = token
    agent.api_key_hash = Agent.api_key_hash(token)
    agent.api_key_last_rotated_at = Time.current
    agent.save!
    agent
  end

  def build_match(agent_a:, agent_b:, game_key:, preset_key:, rated: false)
    preset = TimeControlPreset.find_by!(key: preset_key)
    Match.create!(
      agent_a: agent_a,
      agent_b: agent_b,
      game_key: game_key,
      status: "queued",
      rated: rated,
      time_control: preset.category,
      time_control_preset: preset
    )
  end

  def with_stubbed_http(responses, payloads: [])
    queue = responses.dup
    http = Object.new
    http.define_singleton_method(:request) do |request|
      payloads << JSON.parse(request.body)
      response = queue.shift || {}
      sleep(response[:sleep]) if response[:sleep]
      raise response[:raise] if response[:raise]

      Struct.new(:code, :body).new(
        response.fetch(:code, "200"),
        response.fetch(:body, "{\"move\":\"resign\"}")
      )
    end

    singleton = class << Net::HTTP; self; end
    original_start = Net::HTTP.method(:start)
    singleton.define_method(:start) do |*_args, **_kwargs, &blk|
      blk.call(http)
    end

    yield
  ensure
    singleton.define_method(:start, original_start)
  end

  test "resign finishes chess match with correct winner metadata" do
    a = create_agent("MR1")
    b = create_agent("MR2")
    match = build_match(agent_a: a, agent_b: b, game_key: "chess", preset_key: "test_chess_rapid_10p0")

    payloads = []
    with_stubbed_http([ { body: "{\"move\":\"resign\"}" } ], payloads: payloads) do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    assert_equal "0-1", match.result
    assert_equal "b", match.winner_side
    assert_equal "resign", match.termination
    assert_equal "a", match.resigned_by_side
    assert_equal "white", payloads.first["you_are"]
  end

  test "agent request failure records no_response when clock remains" do
    a = create_agent("MR3")
    b = create_agent("MR4")
    match = build_match(agent_a: a, agent_b: b, game_key: "chess", preset_key: "test_chess_rapid_10p0")

    with_stubbed_http([ { code: "500", body: "{}" } ]) do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    assert_equal "no_response", match.termination
    assert_equal "a", match.forfeit_by_side
    assert_equal "0-1", match.result
    assert_equal "b", match.winner_side
  end

  test "slow failing move request causes time_loss" do
    a = create_agent("MR5")
    b = create_agent("MR6")
    preset = TimeControlPreset.create!(
      key: "test_chess_fast_timeout_1p0",
      game_key: "chess",
      category: "bullet",
      clock_type: "increment",
      clock_config: { base_seconds: 0.01, increment_seconds: 0 },
      rated_allowed: true
    )
    match = Match.create!(
      agent_a: a,
      agent_b: b,
      game_key: "chess",
      status: "queued",
      rated: false,
      time_control: preset.category,
      time_control_preset: preset
    )

    with_stubbed_http([ { code: "500", body: "{}", sleep: 0.05 } ]) do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    assert_equal "time_loss", match.termination
    assert_equal "a", match.forfeit_by_side
    assert_equal "0-1", match.result
    assert_equal "b", match.winner_side
  end

  test "go resignation maps winner by actor scoring" do
    a = create_agent("MR7")
    b = create_agent("MR8")
    match = build_match(agent_a: a, agent_b: b, game_key: "go", preset_key: "test_go_rapid_10m_5x30")

    with_stubbed_http([ { body: "{\"move\":\"resign\"}" } ]) do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    assert_equal "1-0", match.result
    assert_equal "b", match.winner_side
    assert_equal "resign", match.termination
    assert_equal "a", match.resigned_by_side
  end

  test "illegal move yields forfeit" do
    a = create_agent("MR9")
    b = create_agent("MR10")
    match = build_match(agent_a: a, agent_b: b, game_key: "chess", preset_key: "test_chess_rapid_10p0")

    with_stubbed_http([ { body: "{\"move\":\"badmove\"}" } ]) do
      MatchRunner.new(match).run!
    end

    match.reload
    assert_equal "finished", match.status
    assert_equal "illegal_move", match.termination
    assert_equal "a", match.forfeit_by_side
    assert_equal "0-1", match.result
    assert_equal "b", match.winner_side
  end
end
