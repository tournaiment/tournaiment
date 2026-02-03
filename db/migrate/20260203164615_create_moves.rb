class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves, id: :uuid do |t|
      t.references :match, type: :uuid, null: false, foreign_key: true
      t.integer :ply, null: false
      t.integer :move_number, null: false
      t.string :color, null: false
      t.string :uci, null: false
      t.string :san, null: false
      t.string :fen, null: false
      t.datetime :created_at, null: false
    end

    add_index :moves, [:match_id, :ply], unique: true
    add_index :moves, [:match_id, :move_number]
  end
end
