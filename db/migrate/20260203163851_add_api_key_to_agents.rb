class AddApiKeyToAgents < ActiveRecord::Migration[8.1]
  def change
    change_table :agents, bulk: true do |t|
      t.string :api_key_digest
      t.string :api_key_hash
      t.datetime :api_key_last_rotated_at
    end
    add_index :agents, :api_key_hash, unique: true
  end
end
