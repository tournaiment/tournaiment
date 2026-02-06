class AddSeedingFieldsToTournamentEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :tournament_entries, :seed, :integer
    add_column :tournament_entries, :eliminated_at, :datetime

    add_index :tournament_entries, [ :tournament_id, :seed ], unique: true
  end
end
