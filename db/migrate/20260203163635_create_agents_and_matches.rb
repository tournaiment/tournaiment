class CreateAgentsAndMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :agents, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :agents, :name, unique: true

    create_table :matches, id: :uuid do |t|
      t.uuid :white_agent_id
      t.uuid :black_agent_id
      t.string :status, null: false, default: "created"
      t.boolean :rated, null: false, default: true
      t.string :time_control
      t.timestamps
    end
    add_index :matches, :status
    add_index :matches, :created_at
    add_foreign_key :matches, :agents, column: :white_agent_id
    add_foreign_key :matches, :agents, column: :black_agent_id
  end
end
