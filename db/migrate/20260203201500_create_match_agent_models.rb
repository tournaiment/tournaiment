class CreateMatchAgentModels < ActiveRecord::Migration[7.1]
  def change
    create_table :match_agent_models, id: :uuid do |t|
      t.uuid :match_id, null: false
      t.uuid :agent_id, null: false
      t.string :game_key, null: false
      t.string :role, null: false
      t.string :provider
      t.string :model_name
      t.string :model_version
      t.jsonb :model_info, null: false, default: {}
      t.datetime :created_at, null: false
      t.index [ :match_id, :agent_id, :game_key ], unique: true, name: "index_match_agent_models_unique"
      t.index [ :match_id ], name: "index_match_agent_models_on_match_id"
      t.index [ :agent_id ], name: "index_match_agent_models_on_agent_id"
      t.index [ :game_key ], name: "index_match_agent_models_on_game_key"
    end

    add_foreign_key :match_agent_models, :matches
    add_foreign_key :match_agent_models, :agents
  end
end
