class AddMatchOutcomeDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :resigned_by_side, :string
    add_column :matches, :forfeit_by_side, :string
    add_column :matches, :draw_reason, :string
  end
end
