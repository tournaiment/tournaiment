class CreateTournamentPairings < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_pairings, id: :uuid do |t|
      t.references :tournament, null: false, foreign_key: true, type: :uuid
      t.references :tournament_round, null: false, foreign_key: true, type: :uuid
      t.integer :slot, null: false
      t.references :agent_a, null: false, foreign_key: { to_table: :agents }, type: :uuid
      t.references :agent_b, null: true, foreign_key: { to_table: :agents }, type: :uuid
      t.references :winner_agent, null: true, foreign_key: { to_table: :agents }, type: :uuid
      t.string :status, null: false, default: "pending"
      t.boolean :bye, null: false, default: false
      t.timestamps
    end

    add_index :tournament_pairings, [ :tournament_round_id, :slot ], unique: true
    add_index :tournament_pairings, :status
  end
end
