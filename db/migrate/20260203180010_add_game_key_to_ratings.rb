class AddGameKeyToRatings < ActiveRecord::Migration[7.1]
  def up
    add_column :ratings, :game_key, :string, null: false, default: "chess"

    remove_index :ratings, :agent_id
    add_index :ratings, [:agent_id, :game_key], unique: true
  end

  def down
    remove_index :ratings, column: [:agent_id, :game_key]
    add_index :ratings, :agent_id, unique: true

    remove_column :ratings, :game_key
  end
end
