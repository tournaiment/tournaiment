ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    setup do
      ensure_default_time_control_presets!
    end

    private

    def ensure_default_time_control_presets!
      TimeControlPreset.find_or_create_by!(key: "test_chess_rapid_10p0") do |preset|
        preset.game_key = "chess"
        preset.category = "rapid"
        preset.clock_type = "increment"
        preset.clock_config = { base_seconds: 600, increment_seconds: 0 }
        preset.rated_allowed = true
        preset.active = true
      end

      TimeControlPreset.find_or_create_by!(key: "test_chess_blitz_3p2") do |preset|
        preset.game_key = "chess"
        preset.category = "blitz"
        preset.clock_type = "increment"
        preset.clock_config = { base_seconds: 180, increment_seconds: 2 }
        preset.rated_allowed = true
        preset.active = true
      end

      TimeControlPreset.find_or_create_by!(key: "test_go_rapid_10m_5x30") do |preset|
        preset.game_key = "go"
        preset.category = "rapid"
        preset.clock_type = "byoyomi"
        preset.clock_config = { main_time_seconds: 600, period_time_seconds: 30, periods: 5 }
        preset.rated_allowed = true
        preset.active = true
      end
    end

    def create_operator_account(
      email: nil,
      password: "password123!",
      plan: PlanEntitlement::FREE,
      addon_seats: 0,
      billing_interval: StripePriceCatalog::MONTHLY
    )
      account = OperatorAccount.new(
        email: email || "op-#{SecureRandom.hex(6)}@example.test",
        password: password,
        password_confirmation: password,
        email_verified_at: Time.current
      )
      raw_token = OperatorAccount.generate_api_token
      account.api_token = raw_token
      account.api_token_hash = OperatorAccount.api_token_hash(raw_token)
      account.api_token_last_rotated_at = Time.current
      account.save!
      account.entitlement.update!(
        plan: plan,
        addon_seats: addon_seats,
        billing_interval: (plan == PlanEntitlement::PRO ? billing_interval : nil),
        subscription_status: (plan == PlanEntitlement::PRO ? "active" : "inactive"),
        payment_grace_ends_at: nil
      )

      [ account, raw_token ]
    end

    def create_agent_for_operator(operator_account:, name:)
      token = Agent.generate_api_key
      agent = Agent.new(
        name: name,
        metadata: { "move_endpoint" => "http://example.test/move" },
        operator_account: operator_account,
        status: "active"
      )
      agent.api_key = token
      agent.api_key_hash = Agent.api_key_hash(token)
      agent.api_key_last_rotated_at = Time.current
      agent.save!
      [ agent, token ]
    end
  end
end
