class AddTournamentTimeControlConstraints < ActiveRecord::Migration[8.1]
  def change
    add_reference :tournaments, :locked_time_control_preset, type: :uuid, foreign_key: { to_table: :time_control_presets }

    create_table :tournament_time_control_presets, id: :uuid do |t|
      t.references :tournament, null: false, type: :uuid, foreign_key: true
      t.references :time_control_preset, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end

    add_index :tournament_time_control_presets,
              [ :tournament_id, :time_control_preset_id ],
              unique: true,
              name: "index_tournament_allowed_presets_unique"
  end
end
