class AddTournamentPairingToMatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :matches, :tournament_pairing, null: true, foreign_key: true, type: :uuid
  end
end
