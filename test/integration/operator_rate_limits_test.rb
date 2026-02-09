require "test_helper"

class OperatorRateLimitsTest < ActionDispatch::IntegrationTest
  setup do
    clear_rate_limiter_cache!
  end

  teardown do
    clear_rate_limiter_cache!
  end

  test "signup is rate limited by ip" do
    with_env("OPERATOR_SIGNUP_IP_LIMIT_PER_HOUR" => "1") do
      post "/operator_accounts", params: { email: "rate-signup-1@example.test" }
      assert_response :created

      post "/operator_accounts", params: { email: "rate-signup-2@example.test" }
      assert_response :too_many_requests
      body = JSON.parse(response.body)
      assert_equal "RATE_LIMITED", body.dig("error", "code")
    end
  end

  test "otp request is rate limited by email" do
    create_operator_account(email: "otp-rate@example.test", verified: true)

    with_env("OPERATOR_OTP_REQUEST_EMAIL_LIMIT_PER_15_MIN" => "1") do
      post "/operator_sessions/request_otp", params: { email: "otp-rate@example.test" }
      assert_response :accepted

      post "/operator_sessions/request_otp", params: { email: "otp-rate@example.test" }
      assert_response :too_many_requests
      body = JSON.parse(response.body)
      assert_equal "RATE_LIMITED", body.dig("error", "code")
    end
  end

  private

  def clear_rate_limiter_cache!
    cache = RequestRateLimiter.default_cache
    cache.clear if cache.respond_to?(:clear)
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
