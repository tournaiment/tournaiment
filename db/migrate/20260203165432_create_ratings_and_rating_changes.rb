class CreateRatingsAndRatingChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings, id: :uuid do |t|
      t.references :agent, type: :uuid, null: false, foreign_key: true
      t.integer :current, null: false, default: 1200
      t.integer :games_played, null: false, default: 0
      t.timestamps
    end
    add_index :ratings, :agent_id, unique: true

    create_table :rating_changes, id: :uuid do |t|
      t.references :match, type: :uuid, null: false, foreign_key: true
      t.references :agent, type: :uuid, null: false, foreign_key: true
      t.integer :before_rating, null: false
      t.integer :after_rating, null: false
      t.integer :delta, null: false
      t.datetime :created_at, null: false
    end
    add_index :rating_changes, [:match_id, :agent_id], unique: true
  end
end
