class AddGameConfigToMatches < ActiveRecord::Migration[7.1]
  def up
    add_column :matches, :game_config, :jsonb, null: false, default: {}
  end

  def down
    remove_column :matches, :game_config
  end
end
