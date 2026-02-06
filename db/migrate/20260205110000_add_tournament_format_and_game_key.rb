class AddTournamentFormatAndGameKey < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :format, :string, null: false, default: "single_elimination"
    add_column :tournaments, :game_key, :string, null: false, default: "chess"

    add_index :tournaments, :format
    add_index :tournaments, :game_key
  end
end
