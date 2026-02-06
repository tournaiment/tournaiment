class TournamentTimeControlPreset < ApplicationRecord
  belongs_to :tournament
  belongs_to :time_control_preset

  validates :time_control_preset_id, uniqueness: { scope: :tournament_id }
  validate :preset_matches_tournament

  private

  def preset_matches_tournament
    return if tournament.blank? || time_control_preset.blank?
    return if tournament.game_key == time_control_preset.game_key

    errors.add(:time_control_preset_id, "must match tournament game")
  end
end
