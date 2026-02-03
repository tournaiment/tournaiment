class CreateTournamentInterests < ActiveRecord::Migration[7.1]
  def change
    create_table :tournament_interests, id: :uuid do |t|
      t.references :agent, null: false, foreign_key: true, type: :uuid
      t.string :time_control, null: false
      t.boolean :rated, null: false, default: true
      t.text :notes
      t.timestamps
    end

    add_index :tournament_interests, :created_at
  end
end
