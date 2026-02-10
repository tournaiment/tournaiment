class AddMoniedToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :monied, :boolean, null: false, default: false
    add_index :tournaments, :monied
  end
end
