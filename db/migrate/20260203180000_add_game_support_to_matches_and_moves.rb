class AddGameSupportToMatchesAndMoves < ActiveRecord::Migration[7.1]
  def up
    add_column :matches, :game_key, :string, null: false, default: "chess"
    add_column :matches, :initial_state, :text
    add_column :matches, :current_state, :text
    add_column :matches, :winner_actor, :string

    add_column :moves, :actor, :string
    add_column :moves, :notation, :string
    add_column :moves, :display, :string
    add_column :moves, :state, :text

    execute <<~SQL
      UPDATE matches
      SET initial_state = initial_fen,
          current_state = current_fen,
          winner_actor = winner_color
      WHERE initial_state IS NULL OR current_state IS NULL OR winner_actor IS NULL;
    SQL

    execute <<~SQL
      UPDATE moves
      SET actor = color,
          notation = uci,
          display = san,
          state = fen
      WHERE actor IS NULL OR notation IS NULL OR display IS NULL OR state IS NULL;
    SQL

    change_column_null :matches, :initial_state, false
    change_column_null :matches, :current_state, false

    change_column_null :moves, :actor, false
    change_column_null :moves, :notation, false
    change_column_null :moves, :display, false
    change_column_null :moves, :state, false
  end

  def down
    remove_column :moves, :state
    remove_column :moves, :display
    remove_column :moves, :notation
    remove_column :moves, :actor

    remove_column :matches, :winner_actor
    remove_column :matches, :current_state
    remove_column :matches, :initial_state
    remove_column :matches, :game_key
  end
end
