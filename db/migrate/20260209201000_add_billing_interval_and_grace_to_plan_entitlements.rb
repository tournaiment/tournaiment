class AddBillingIntervalAndGraceToPlanEntitlements < ActiveRecord::Migration[8.1]
  def change
    add_column :plan_entitlements, :billing_interval, :string
    add_column :plan_entitlements, :payment_grace_ends_at, :datetime

    add_index :plan_entitlements, :billing_interval
    add_index :plan_entitlements, :payment_grace_ends_at
  end
end
