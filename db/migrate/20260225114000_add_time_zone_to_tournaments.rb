class AddTimeZoneToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :time_zone, :string, null: false, default: "UTC"
  end
end
