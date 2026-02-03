class AddChessFieldsToMatches < ActiveRecord::Migration[8.1]
  def change
    starting_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    change_table :matches, bulk: true do |t|
      t.string :initial_fen, null: false, default: starting_fen
      t.string :current_fen, null: false, default: starting_fen
      t.text :pgn
      t.string :result
      t.string :winner_color
      t.string :termination
      t.integer :ply_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
    end
  end
end
