require "test_helper"

class StripePriceCatalogTest < ActiveSupport::TestCase
  test "normalizes supported intervals" do
    assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.normalize_interval(nil)
    assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.normalize_interval("monthly")
    assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.normalize_interval("month")
    assert_nil StripePriceCatalog.normalize_interval("weekly")
    assert_nil StripePriceCatalog.normalize_interval("yearly")
  end

  test "strict interval normalization requires explicit value" do
    assert_nil StripePriceCatalog.normalize_interval_strict(nil)
    assert_nil StripePriceCatalog.normalize_interval_strict("")
    assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.normalize_interval_strict("monthly")
    assert_nil StripePriceCatalog.normalize_interval_strict("yearly")
  end

  test "returns monthly pro price with legacy fallback" do
    with_env(
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_monthly",
      "STRIPE_PRO_PRICE_ID" => "price_pro_legacy"
    ) do
      assert_equal "price_pro_monthly", StripePriceCatalog.pro_price_id
    end

    with_env(
      "STRIPE_PRO_PRICE_ID_MONTHLY" => nil,
      "STRIPE_PRO_PRICE_ID" => "price_pro_legacy"
    ) do
      assert_equal "price_pro_legacy", StripePriceCatalog.pro_price_id
    end
  end

  test "returns monthly seat addon price with legacy fallback" do
    with_env(
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_monthly",
      "STRIPE_SEAT_ADDON_PRICE_ID" => "price_seat_legacy"
    ) do
      assert_equal "price_seat_monthly", StripePriceCatalog.seat_addon_price_id
    end

    with_env(
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => nil,
      "STRIPE_SEAT_ADDON_PRICE_ID" => "price_seat_legacy"
    ) do
      assert_equal "price_seat_legacy", StripePriceCatalog.seat_addon_price_id
    end
  end

  test "detects known price interval by configured ids" do
    with_env(
      "STRIPE_PRO_PRICE_ID_MONTHLY" => "price_pro_monthly",
      "STRIPE_SEAT_ADDON_PRICE_ID_MONTHLY" => "price_seat_monthly",
      "STRIPE_PRO_PRICE_ID" => "price_pro_legacy",
      "STRIPE_SEAT_ADDON_PRICE_ID" => "price_seat_legacy"
    ) do
      assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.interval_for_known_price_id("price_pro_monthly")
      assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.interval_for_known_price_id("price_seat_monthly")
      assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.interval_for_known_price_id("price_pro_legacy")
      assert_equal StripePriceCatalog::MONTHLY, StripePriceCatalog.interval_for_known_price_id("price_seat_legacy")
      assert_nil StripePriceCatalog.interval_for_known_price_id("price_unknown")
    end
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
