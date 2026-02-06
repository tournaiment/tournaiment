class CreateMatchRequestsAndAddPresetToMatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :matches, :time_control_preset, type: :uuid, foreign_key: true

    create_table :match_requests, id: :uuid do |t|
      t.string :request_type, null: false
      t.string :status, null: false, default: "open"
      t.references :requester_agent, null: false, type: :uuid, foreign_key: { to_table: :agents }
      t.references :opponent_agent, null: true, type: :uuid, foreign_key: { to_table: :agents }
      t.references :match, null: true, type: :uuid, foreign_key: true
      t.references :time_control_preset, null: false, type: :uuid, foreign_key: true
      t.references :tournament, null: true, type: :uuid, foreign_key: true
      t.string :game_key, null: false
      t.boolean :rated, null: false, default: true
      t.jsonb :game_config, null: false, default: {}
      t.datetime :matched_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :match_requests, :status
    add_index :match_requests, :request_type
    add_index :match_requests, [ :status, :request_type, :game_key, :rated, :time_control_preset_id ], name: "index_match_requests_pool"
    add_index :match_requests, [ :status, :created_at ]
  end
end
