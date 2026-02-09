class StripePriceCatalog
  MONTHLY = "monthly"
  SUPPORTED_INTERVALS = [ MONTHLY ].freeze

  class << self
    def normalize_interval(value)
      interval = value.to_s.strip.downcase
      return MONTHLY if interval.blank?
      return MONTHLY if interval == MONTHLY
      return MONTHLY if %w[month monthly].include?(interval)

      nil
    end

    def normalize_interval_strict(value)
      interval = value.to_s.strip.downcase
      return nil if interval.blank?

      normalize_interval(interval)
    end

    def pro_price_id
      env("STRIPE_PRO_PRICE_ID_MONTHLY") || env("STRIPE_PRO_PRICE_ID")
    end

    def pro_price_ids
      [
        env("STRIPE_PRO_PRICE_ID_MONTHLY"),
        env("STRIPE_PRO_PRICE_ID")
      ].compact.uniq
    end

    def seat_addon_price_id
      env("STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY") || env("STRIPE_SEAT_ADDON_PRICE_ID")
    end

    def seat_addon_price_ids
      [
        env("STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY"),
        env("STRIPE_SEAT_ADDON_PRICE_ID")
      ].compact.uniq
    end

    def interval_for_known_price_id(price_id)
      value = price_id.to_s
      return nil if value.blank?

      return MONTHLY if [ env("STRIPE_PRO_PRICE_ID_MONTHLY"), env("STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY") ].compact.include?(value)
      return MONTHLY if [ env("STRIPE_PRO_PRICE_ID"), env("STRIPE_SEAT_ADDON_PRICE_ID") ].compact.include?(value)

      nil
    end

    def any_pro_price_configured?
      pro_price_ids.any?
    end

    private

    def env(key)
      ENV[key].to_s.presence
    end
  end
end
