class StripeConfigHealthCheckService
  DEFAULT_GRACE_DAYS = 7

  def initialize(verify_remote: false, env: ENV, rails_env: Rails.env, stripe_client: nil)
    @verify_remote = verify_remote
    @env = env
    @rails_env = rails_env.to_s
    @stripe_client = stripe_client
    @stripe_client_error = nil
  end

  def call
    checks = []
    checks << stripe_secret_key_check
    checks << stripe_webhook_secret_check
    checks << pro_price_id_check
    checks << seat_addon_price_id_check
    checks << grace_days_check
    checks.concat(remote_price_checks)

    counts = {
      ok: checks.count { |check| check[:status] == :ok },
      warning: checks.count { |check| check[:status] == :warning },
      error: checks.count { |check| check[:status] == :error }
    }

    {
      checked_at: Time.current,
      verify_remote: @verify_remote,
      overall_status: overall_status(counts),
      counts: counts,
      checks: checks
    }
  end

  private

  def stripe_secret_key_check
    key = stripe_secret_key
    return check(:stripe_secret_key, "STRIPE_SECRET_KEY", :error, "Missing Stripe secret key.") if key.blank?

    status = :ok
    message = "Stripe secret key is present."

    unless key.start_with?("sk_test_", "sk_live_")
      status = :warning
      message = "Secret key format is unexpected."
    end

    if @rails_env == "production" && key.start_with?("sk_test_")
      status = :error
      message = "Production is configured with a test secret key."
    elsif @rails_env != "production" && key.start_with?("sk_live_")
      status = :warning
      message = "Non-production environment is using a live secret key."
    end

    check(:stripe_secret_key, "STRIPE_SECRET_KEY", status, message, value: mask_key(key))
  end

  def stripe_webhook_secret_check
    secret = env_value("STRIPE_WEBHOOK_SECRET")
    return check(:stripe_webhook_secret, "STRIPE_WEBHOOK_SECRET", :error, "Missing Stripe webhook secret.") if secret.blank?

    status = secret.start_with?("whsec_") ? :ok : :warning
    message = status == :ok ? "Stripe webhook secret is present." : "Webhook secret format is unexpected."
    check(:stripe_webhook_secret, "STRIPE_WEBHOOK_SECRET", status, message, value: mask_key(secret))
  end

  def pro_price_id_check
    id = pro_price_id
    return check(:pro_price_id, "STRIPE_PRO_PRICE_ID_MONTHLY", :error, "Missing Pro monthly price id.") if id.blank?

    status = id.start_with?("price_") ? :ok : :warning
    message = status == :ok ? "Pro monthly price id is configured." : "Price id format is unexpected."
    check(:pro_price_id, "STRIPE_PRO_PRICE_ID_MONTHLY", status, message, value: id)
  end

  def seat_addon_price_id_check
    id = seat_addon_price_id
    return check(:seat_addon_price_id, "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY", :error, "Missing seat add-on monthly price id.") if id.blank?

    status = id.start_with?("price_") ? :ok : :warning
    message = status == :ok ? "Seat add-on monthly price id is configured." : "Price id format is unexpected."
    check(:seat_addon_price_id, "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY", status, message, value: id)
  end

  def grace_days_check
    raw = env_value("BILLING_PAST_DUE_GRACE_DAYS")
    if raw.blank?
      return check(
        :grace_days,
        "BILLING_PAST_DUE_GRACE_DAYS",
        :warning,
        "Grace days is not set; default of #{DEFAULT_GRACE_DAYS} will be used.",
        value: DEFAULT_GRACE_DAYS
      )
    end

    value = Integer(raw)
    if value.negative?
      return check(:grace_days, "BILLING_PAST_DUE_GRACE_DAYS", :error, "Grace days must be >= 0.", value: raw)
    end

    check(:grace_days, "BILLING_PAST_DUE_GRACE_DAYS", :ok, "Grace days is valid.", value: value)
  rescue ArgumentError, TypeError
    check(:grace_days, "BILLING_PAST_DUE_GRACE_DAYS", :error, "Grace days must be an integer.", value: raw)
  end

  def remote_price_checks
    return [ check(:remote_verify, "Remote Stripe Verify", :ok, "Skipped. Use verify=1 to run live checks.") ] unless @verify_remote

    client = resolved_stripe_client
    unless client
      return [ check(:remote_verify, "Remote Stripe Verify", :error, @stripe_client_error || "Unable to initialize Stripe API client.") ]
    end

    [
      verify_remote_price(client:, price_id: pro_price_id, label: "Stripe Pro Monthly Price"),
      verify_remote_price(client:, price_id: seat_addon_price_id, label: "Stripe Seat Add-on Monthly Price")
    ]
  end

  def verify_remote_price(client:, price_id:, label:)
    return check(label.parameterize(separator: "_").to_sym, label, :error, "Missing price id; cannot verify remotely.") if price_id.blank?

    price = client.retrieve_price(price_id)
    active = price["active"] == true
    recurring_interval = price.dig("recurring", "interval").to_s
    recurring_type = price["type"].to_s

    unless active
      return check(label.parameterize(separator: "_").to_sym, label, :error, "Stripe price exists but is not active.", value: price_id)
    end

    unless recurring_type == "recurring" && recurring_interval == "month"
      return check(
        label.parameterize(separator: "_").to_sym,
        label,
        :error,
        "Stripe price must be active monthly recurring.",
        value: price_id
      )
    end

    check(
      label.parameterize(separator: "_").to_sym,
      label,
      :ok,
      "Verified active monthly recurring price in Stripe.",
      value: price_id
    )
  rescue StripeApiClient::Error => e
    check(label.parameterize(separator: "_").to_sym, label, :error, "Stripe API error: #{e.message}", value: price_id)
  end

  def resolved_stripe_client
    return @stripe_client if @stripe_client

    @stripe_client = StripeApiClient.new(secret_key: stripe_secret_key)
  rescue StripeApiClient::Error => e
    @stripe_client_error = e.message
    nil
  end

  def stripe_secret_key
    env_value("STRIPE_SECRET_KEY")
  end

  def pro_price_id
    env_value("STRIPE_PRO_PRICE_ID_MONTHLY") || env_value("STRIPE_PRO_PRICE_ID")
  end

  def seat_addon_price_id
    env_value("STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY") || env_value("STRIPE_SEAT_ADDON_PRICE_ID")
  end

  def env_value(key)
    @env[key].to_s.strip.presence
  end

  def check(key, label, status, message, value: nil)
    {
      key: key.to_s,
      label: label,
      status: status,
      message: message,
      value: value
    }
  end

  def overall_status(counts)
    return :error if counts[:error].positive?
    return :warning if counts[:warning].positive?

    :ok
  end

  def mask_key(value)
    return nil if value.blank?
    return "#{value[0, 4]}..." if value.length <= 8

    "#{value[0, 8]}...#{value[-4, 4]}"
  end
end
