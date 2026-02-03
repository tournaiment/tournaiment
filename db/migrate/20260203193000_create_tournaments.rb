class CreateTournaments < ActiveRecord::Migration[7.1]
  def change
    create_table :tournaments, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "registration_open"
      t.string :time_control, null: false, default: "rapid"
      t.boolean :rated, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :max_players
      t.timestamps
    end

    add_index :tournaments, :status
  end
end
