class CreateOperatorOneTimePasscodes < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_one_time_passcodes, id: :uuid do |t|
      t.references :operator_account, null: false, type: :uuid, foreign_key: true
      t.string :purpose, null: false
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.integer :attempt_count, null: false, default: 0
      t.string :requested_ip

      t.timestamps
    end

    add_index :operator_one_time_passcodes, [ :operator_account_id, :purpose, :consumed_at ],
              name: "index_operator_otps_on_account_purpose_consumed"
    add_index :operator_one_time_passcodes, :expires_at
  end
end
