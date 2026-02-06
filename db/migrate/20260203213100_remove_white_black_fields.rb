class RemoveWhiteBlackFields < ActiveRecord::Migration[7.1]
  def up
    remove_foreign_key :matches, column: :white_agent_id if foreign_key_exists?(:matches, column: :white_agent_id)
    remove_foreign_key :matches, column: :black_agent_id if foreign_key_exists?(:matches, column: :black_agent_id)

    remove_column :matches, :white_agent_id
    remove_column :matches, :black_agent_id
    remove_column :matches, :winner_actor
    remove_column :matches, :winner_color
  end

  def down
    add_column :matches, :white_agent_id, :uuid
    add_column :matches, :black_agent_id, :uuid
    add_column :matches, :winner_actor, :string
    add_column :matches, :winner_color, :string

    add_foreign_key :matches, :agents, column: :white_agent_id
    add_foreign_key :matches, :agents, column: :black_agent_id
  end
end
