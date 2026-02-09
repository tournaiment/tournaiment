require "bcrypt"
require "digest"

class AddOperatorAccountsAndPlanEntitlements < ActiveRecord::Migration[8.1]
  def up
    create_table :operator_accounts, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :api_token_digest
      t.string :api_token_hash
      t.datetime :api_token_last_rotated_at
      t.datetime :email_verified_at
      t.string :status, null: false, default: "active"
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :operator_accounts, :email, unique: true
    add_index :operator_accounts, :api_token_hash, unique: true
    add_index :operator_accounts, :status

    create_table :plan_entitlements, id: :uuid do |t|
      t.references :operator_account, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :plan, null: false, default: "free"
      t.integer :addon_seats, null: false, default: 0
      t.string :subscription_status, null: false, default: "inactive"
      t.datetime :current_period_ends_at
      t.timestamps
    end
    add_index :plan_entitlements, :plan
    add_index :plan_entitlements, :subscription_status

    add_reference :agents, :operator_account, type: :uuid, foreign_key: true
    add_column :agents, :status, :string, null: false, default: "active"
    add_index :agents, :status

    create_legacy_operator_account!
    change_column_null :agents, :operator_account_id, false
  end

  def down
    remove_index :agents, :status
    remove_column :agents, :status
    remove_reference :agents, :operator_account, type: :uuid, foreign_key: true

    drop_table :plan_entitlements
    drop_table :operator_accounts
  end

  private

  def create_legacy_operator_account!
    legacy_operator_id = "00000000-0000-0000-0000-000000000001"
    legacy_entitlement_id = "00000000-0000-0000-0000-000000000002"
    now = Time.current
    raw_password = SecureRandom.hex(32)
    raw_token = SecureRandom.hex(32)
    token_hash = Digest::SHA256.hexdigest(raw_token)
    password_digest = BCrypt::Password.create(raw_password)
    token_digest = BCrypt::Password.create(raw_token)
    now_sql = connection.quote(now)
    legacy_operator_id_sql = connection.quote(legacy_operator_id)
    legacy_entitlement_id_sql = connection.quote(legacy_entitlement_id)
    legacy_email_sql = connection.quote("legacy-system@tournaiment.local")
    password_digest_sql = connection.quote(password_digest.to_s)
    token_digest_sql = connection.quote(token_digest.to_s)
    token_hash_sql = connection.quote(token_hash)

    execute <<~SQL.squish
      INSERT INTO operator_accounts
      (id, email, password_digest, api_token_digest, api_token_hash, api_token_last_rotated_at, email_verified_at, status, metadata, created_at, updated_at)
      VALUES
      (#{legacy_operator_id_sql}, #{legacy_email_sql}, #{password_digest_sql},
       #{token_digest_sql}, #{token_hash_sql}, #{now_sql}, #{now_sql}, 'active', '{}'::jsonb, #{now_sql}, #{now_sql});
    SQL

    execute <<~SQL.squish
      INSERT INTO plan_entitlements
      (id, operator_account_id, plan, addon_seats, subscription_status, created_at, updated_at)
      VALUES
      (#{legacy_entitlement_id_sql}, #{legacy_operator_id_sql}, 'pro', 10000, 'legacy_grandfathered', #{now_sql}, #{now_sql});
    SQL

    execute <<~SQL.squish
      UPDATE agents
      SET operator_account_id = #{legacy_operator_id_sql},
          status = COALESCE(status, 'active')
      WHERE operator_account_id IS NULL;
    SQL
  end
end
