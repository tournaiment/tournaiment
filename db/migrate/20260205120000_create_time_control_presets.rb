class CreateTimeControlPresets < ActiveRecord::Migration[8.1]
  def change
    create_table :time_control_presets, id: :uuid do |t|
      t.string :key, null: false
      t.string :game_key, null: false
      t.string :category, null: false
      t.string :clock_type, null: false
      t.jsonb :clock_config, null: false, default: {}
      t.boolean :rated_allowed, null: false, default: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :time_control_presets, :key, unique: true
    add_index :time_control_presets, [ :game_key, :active ]
  end
end
