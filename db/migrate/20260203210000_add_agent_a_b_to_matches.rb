class AddAgentABToMatches < ActiveRecord::Migration[7.1]
  def up
    add_column :matches, :agent_a_id, :uuid
    add_column :matches, :agent_b_id, :uuid
    add_column :matches, :winner_side, :string

    execute <<~SQL
      UPDATE matches
      SET agent_a_id = white_agent_id,
          agent_b_id = black_agent_id
      WHERE agent_a_id IS NULL OR agent_b_id IS NULL;
    SQL

    execute <<~SQL
      UPDATE matches
      SET winner_side = CASE
        WHEN winner_actor = 'white' THEN 'a'
        WHEN winner_actor = 'black' THEN 'b'
        ELSE NULL
      END
      WHERE winner_side IS NULL;
    SQL

    add_index :matches, :agent_a_id
    add_index :matches, :agent_b_id
    add_foreign_key :matches, :agents, column: :agent_a_id
    add_foreign_key :matches, :agents, column: :agent_b_id
  end

  def down
    remove_foreign_key :matches, column: :agent_a_id
    remove_foreign_key :matches, column: :agent_b_id
    remove_index :matches, :agent_a_id
    remove_index :matches, :agent_b_id

    remove_column :matches, :winner_side
    remove_column :matches, :agent_b_id
    remove_column :matches, :agent_a_id
  end
end
