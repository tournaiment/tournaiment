require "digest"

class OperatorOtpService
  Result = Struct.new(:success?, :reason, keyword_init: true)

  DEFAULT_TTL_SECONDS = 10.minutes.to_i
  DEFAULT_MAX_ATTEMPTS = 5

  def initialize(now: Time.current)
    @now = now
  end

  def issue!(operator_account:, purpose:, ip_address: nil, code: nil)
    validate_purpose!(purpose)
    raw_code = normalize_code(code).presence || generate_code
    digest = digest_code(raw_code)

    OperatorOneTimePasscode.transaction do
      operator_account.operator_one_time_passcodes.active.where(purpose: purpose)
                    .update_all(consumed_at: @now, updated_at: @now)

      operator_account.operator_one_time_passcodes.create!(
        purpose: purpose,
        code_digest: digest,
        expires_at: @now + ttl_seconds.seconds,
        requested_ip: ip_address
      )
    end

    raw_code
  end

  def verify!(operator_account:, purpose:, code:)
    validate_purpose!(purpose)
    normalized_code = normalize_code(code)
    return Result.new(success?: false, reason: :invalid_code) if normalized_code.blank?

    record = operator_account.operator_one_time_passcodes.where(purpose: purpose).unconsumed.order(created_at: :desc).first
    return Result.new(success?: false, reason: :not_found) unless record

    record.with_lock do
      return consume_and_fail!(record, :expired) if record.expired?

      attempts = record.attempt_count + 1
      if secure_compare(record.code_digest, digest_code(normalized_code))
        record.update!(consumed_at: @now, attempt_count: attempts)
        return Result.new(success?: true, reason: :ok)
      end

      consume_now = attempts >= max_attempts
      record.update!(
        attempt_count: attempts,
        consumed_at: consume_now ? @now : nil
      )
      Result.new(success?: false, reason: consume_now ? :too_many_attempts : :invalid_code)
    end
  end

  private

  def validate_purpose!(purpose)
    return if OperatorOneTimePasscode::PURPOSES.include?(purpose.to_s)

    raise ArgumentError, "Unsupported OTP purpose: #{purpose.inspect}"
  end

  def normalize_code(code)
    code.to_s.gsub(/\D/, "")[0, 6]
  end

  def generate_code
    format("%06d", SecureRandom.random_number(1_000_000))
  end

  def digest_code(code)
    Digest::SHA256.hexdigest("#{otp_pepper}:#{code}")
  end

  def otp_pepper
    ENV["OPERATOR_OTP_PEPPER"].to_s
  end

  def ttl_seconds
    Integer(ENV.fetch("OPERATOR_OTP_TTL_SECONDS", DEFAULT_TTL_SECONDS.to_s))
  rescue ArgumentError, TypeError
    DEFAULT_TTL_SECONDS
  end

  def max_attempts
    Integer(ENV.fetch("OPERATOR_OTP_MAX_ATTEMPTS", DEFAULT_MAX_ATTEMPTS.to_s))
  rescue ArgumentError, TypeError
    DEFAULT_MAX_ATTEMPTS
  end

  def secure_compare(a, b)
    return false if a.blank? || b.blank?
    return false unless a.bytesize == b.bytesize

    ActiveSupport::SecurityUtils.secure_compare(a, b)
  end

  def consume_and_fail!(record, reason)
    record.update!(consumed_at: @now)
    Result.new(success?: false, reason: reason)
  end
end
