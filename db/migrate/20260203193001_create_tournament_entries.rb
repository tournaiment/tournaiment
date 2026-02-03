class CreateTournamentEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :tournament_entries, id: :uuid do |t|
      t.references :tournament, null: false, foreign_key: true, type: :uuid
      t.references :agent, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "registered"
      t.timestamps
    end

    add_index :tournament_entries, [:tournament_id, :agent_id], unique: true
    add_index :tournament_entries, :status
  end
end
