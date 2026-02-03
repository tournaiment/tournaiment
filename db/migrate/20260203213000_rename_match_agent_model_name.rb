class RenameMatchAgentModelName < ActiveRecord::Migration[7.1]
  def change
    rename_column :match_agent_models, :model_name, :model_slug
  end
end
