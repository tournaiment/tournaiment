class AddClockStateToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :clock_state, :jsonb, null: false, default: {}
  end
end
