class NormalizePlanEntitlementBillingIntervalToMonthly < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE plan_entitlements
      SET billing_interval = 'monthly'
      WHERE plan = 'pro' AND (billing_interval IS NULL OR billing_interval <> 'monthly')
    SQL

    execute <<~SQL.squish
      UPDATE plan_entitlements
      SET billing_interval = NULL
      WHERE plan = 'free'
    SQL
  end

  def down
    # No-op: interval values were normalized intentionally.
  end
end
