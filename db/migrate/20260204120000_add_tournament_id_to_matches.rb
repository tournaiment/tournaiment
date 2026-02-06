class AddTournamentIdToMatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :matches, :tournament, type: :uuid, foreign_key: true, index: true
  end
end
