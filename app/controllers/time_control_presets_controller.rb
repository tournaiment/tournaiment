class TimeControlPresetsController < ApplicationController
  def index
    presets = TimeControlPreset.all

    active_param = params[:active]
    active_only = active_param.nil? ? true : truthy?(active_param)
    presets = presets.where(active: true) if active_only

    game_key = params[:game_key].presence
    if game_key.present? && GameRegistry.supported_keys.include?(game_key)
      presets = presets.where(game_key: game_key)
    end

    if truthy?(params[:rated])
      presets = presets.where(rated_allowed: true)
    end

    tournament_id = params[:tournament_id].presence
    if tournament_id.present?
      tournament = Tournament.find_by(id: tournament_id)
      if tournament
        presets = presets.where(game_key: tournament.game_key)
        presets = presets.where(rated_allowed: true) if tournament.rated?
        if tournament.locked_time_control_preset_id.present?
          presets = presets.where(id: tournament.locked_time_control_preset_id)
        elsif tournament.tournament_time_control_presets.exists?
          presets = presets.where(id: tournament.allowed_time_control_presets.select(:id))
        end
      else
        presets = presets.none
      end
    end

    render json: presets.order(:game_key, :category, :key).map { |preset| payload_for(preset) }
  end

  private

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def payload_for(preset)
    {
      id: preset.id,
      key: preset.key,
      game_key: preset.game_key,
      category: preset.category,
      clock_type: preset.clock_type,
      clock_config: preset.clock_config,
      rated_allowed: preset.rated_allowed,
      active: preset.active
    }
  end
end
