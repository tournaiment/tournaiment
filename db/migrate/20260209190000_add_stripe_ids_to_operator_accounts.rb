class AddStripeIdsToOperatorAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :operator_accounts, :stripe_customer_id, :string
    add_column :operator_accounts, :stripe_subscription_id, :string

    add_index :operator_accounts, :stripe_customer_id, unique: true
    add_index :operator_accounts, :stripe_subscription_id, unique: true
  end
end
