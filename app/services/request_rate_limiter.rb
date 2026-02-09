class RequestRateLimiter
  Result = Struct.new(:allowed, :count, :limit, :window_seconds, :retry_after_seconds, keyword_init: true)

  class << self
    def check(key:, limit:, window_seconds:, cache: default_cache, now: Time.current)
      new(cache: cache, now: now).check(key:, limit:, window_seconds:)
    end

    def default_cache
      rails_cache = Rails.cache
      return rails_cache unless rails_cache.is_a?(ActiveSupport::Cache::NullStore)

      @fallback_cache ||= ActiveSupport::Cache::MemoryStore.new
    end
  end

  def initialize(cache:, now:)
    @cache = cache
    @now = now
  end

  def check(key:, limit:, window_seconds:)
    bucket = (@now.to_i / window_seconds)
    cache_key = "rate_limit:#{key}:#{bucket}"
    count = increment(cache_key, expires_in: window_seconds)
    allowed = count <= limit
    retry_after = window_seconds - (@now.to_i % window_seconds)

    Result.new(
      allowed: allowed,
      count: count,
      limit: limit,
      window_seconds: window_seconds,
      retry_after_seconds: retry_after
    )
  end

  private

  def increment(key, expires_in:)
    count = @cache.increment(key, 1, expires_in: expires_in) if @cache.respond_to?(:increment)
    return count.to_i if count

    current = @cache.read(key).to_i + 1
    @cache.write(key, current, expires_in: expires_in)
    current
  end
end
