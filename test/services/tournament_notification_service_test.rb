require "test_helper"
require "openssl"

class TournamentNotificationServiceTest < ActiveSupport::TestCase
  test "adds signed headers when agent secret present" do
    tournament = Tournament.create!(
      name: "Sign Cup",
      status: "running",
      format: "single_elimination",
      game_key: "chess",
      time_control: "rapid",
      rated: true
    )
    agent = Agent.create!(
      name: "SigA1",
      metadata: {
        "tournament_endpoint" => "https://agent.example.com/tournament",
        "tournament_secret" => "shh-secret"
      }
    )

    captured = {}
    http = Object.new
    http.define_singleton_method(:request) do |request|
      captured[:body] = request.body
      captured[:timestamp] = request["X-Tournaiment-Timestamp"]
      captured[:signature] = request["X-Tournaiment-Signature"]
      Struct.new(:code).new("200")
    end

    http_singleton = class << Net::HTTP; self; end
    original_start = Net::HTTP.method(:start)
    http_singleton.define_method(:start) do |*_args, **_kwargs, &blk|
      blk.call(http)
    end

    TournamentNotificationService.new(
      tournament: tournament,
      event: "match_assigned",
      agent_ids: [ agent.id ],
      payload: { round: 1 }
    ).call

    expected = OpenSSL::HMAC.hexdigest("SHA256", "shh-secret", "#{captured[:timestamp]}.#{captured[:body]}")
    assert_equal expected, captured[:signature]
  ensure
    http_singleton.define_method(:start, original_start)
  end
end
