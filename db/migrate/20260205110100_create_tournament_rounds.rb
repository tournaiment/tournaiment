class CreateTournamentRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_rounds, id: :uuid do |t|
      t.references :tournament, null: false, foreign_key: true, type: :uuid
      t.integer :round_number, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :tournament_rounds, [ :tournament_id, :round_number ], unique: true
    add_index :tournament_rounds, :status
  end
end
