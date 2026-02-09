require "test_helper"

class RequestRateLimiterTest < ActiveSupport::TestCase
  test "allows requests until limit then blocks" do
    cache = ActiveSupport::Cache::MemoryStore.new
    now = Time.current

    first = RequestRateLimiter.check(key: "test-key", limit: 2, window_seconds: 60, cache: cache, now: now)
    second = RequestRateLimiter.check(key: "test-key", limit: 2, window_seconds: 60, cache: cache, now: now)
    third = RequestRateLimiter.check(key: "test-key", limit: 2, window_seconds: 60, cache: cache, now: now)

    assert first.allowed
    assert second.allowed
    assert_not third.allowed
    assert third.retry_after_seconds.positive?
  end
end
