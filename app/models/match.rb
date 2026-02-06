class Match < ApplicationRecord
  STATUSES = %w[created queued running finished cancelled failed invalid].freeze

  belongs_to :agent_a, class_name: "Agent", optional: true
  belongs_to :agent_b, class_name: "Agent", optional: true
  belongs_to :tournament, optional: true
  belongs_to :tournament_pairing, optional: true
  belongs_to :time_control_preset, optional: true
  has_many :moves, dependent: :destroy
  has_many :match_agent_models, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :agent_a_id, presence: true
  validate :distinct_agents
  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :current_state, presence: true
  validates :initial_state, presence: true
  validate :preset_matches_game
  validate :rated_preset_allowed
  validate :tournament_constraints

  before_validation :set_initial_state, on: :create
  before_validation :assign_default_rated_time_control_preset
  after_commit :broadcast_state!, on: :update, if: :broadcastable_change?
  after_commit :schedule_tournament_progress!, on: :update, if: :finished_tournament_match?

  def queueable?
    status == "created" && agent_b_id.present?
  end

  def queue!
    transition!(from: "created", to: "queued")
    MatchRunnerJob.perform_later(id)
  end

  def start!
    transition!(from: "queued", to: "running")
  end

  def finish!
    transition!(from: "running", to: "finished")
  end

  def cancel!
    transition!(from: "running", to: "cancelled")
  end

  def fail!
    transition!(from: "running", to: "failed")
  end

  def invalidate!
    transition!(from: "finished", to: "invalid")
  end

  def record_move!(move)
    raise ArgumentError, "Match is not running" unless status == "running"

    update!(started_at: Time.current) if started_at.nil?

    rules = GameRegistry.fetch!(game_key)
    data = rules.apply_move(state: current_state, move: move, actor: next_actor)
    next_ply = ply_count + 1
    move_number = rules.turn_number_for_ply(next_ply)
    actor = rules.actor_for_ply(ply_count)

    moves.create!(
      ply: next_ply,
      move_number: move_number,
      actor: actor,
      notation: data[:notation],
      display: data[:display],
      state: data[:state],
      created_at: Time.current
    )

    update!(
      current_state: data[:state],
      ply_count: next_ply,
      result: (data[:result] == "*" ? nil : data[:result])
    )

    broadcast_state!
  end

  def generate_record!
    rules = GameRegistry.fetch!(game_key)
    ordered_moves = moves.order(:ply).pluck(:display)
    self.pgn = rules.render_record(
      moves: ordered_moves,
      result: result,
      tags: default_tags
    )
    save!
  end

  def public_payload(include_moves: true)
    payload = {
      id: id,
      game_key: game_key,
      status: status,
      result: result,
      rated: rated,
      termination: termination,
      winner_side: winner_side,
      resigned_by_side: resigned_by_side,
      forfeit_by_side: forfeit_by_side,
      draw_reason: draw_reason,
      tournament_id: tournament_id,
      tournament_name: tournament&.name,
      time_control_preset_key: time_control_preset&.key,
      time_control: time_control_payload,
      clock_state: clock_state,
      started_at: started_at,
      finished_at: finished_at,
      initial_state: initial_state,
      current_state: current_state,
      agent_a: agent_a&.name,
      agent_b: agent_b&.name
    }

    if include_moves
      payload[:moves] = moves.order(:ply).map do |move|
        {
          ply: move.ply,
          move_number: move.move_number,
          actor: move.actor,
          notation: move.notation,
          display: move.display,
          state: move.state
        }
      end
    end

    payload
  end

  def broadcast_state!
    ActionCable.server.broadcast("match:#{id}", public_payload)
  end

  def broadcastable_change?
    saved_change_to_status? ||
      saved_change_to_result? ||
      saved_change_to_current_state? ||
      saved_change_to_termination? ||
      saved_change_to_winner_side? ||
      saved_change_to_resigned_by_side? ||
      saved_change_to_forfeit_by_side? ||
      saved_change_to_draw_reason?
  end

  def snapshot_agent_models!
    snapshot_agent_model!(agent_a, "a") if agent_a
    snapshot_agent_model!(agent_b, "b") if agent_b
  end

  def agent_for_actor(actor)
    rules = GameRegistry.fetch!(game_key)
    return agent_a if actor == rules.actors.first
    return agent_b if actor == rules.actors.second

    nil
  end

  def actor_for_agent(agent)
    return nil if agent.nil?
    rules = GameRegistry.fetch!(game_key)
    return rules.actors.first if agent.id == agent_a_id
    return rules.actors.second if agent.id == agent_b_id

    nil
  end

  private

  def time_control_payload
    if time_control_preset
      {
        preset_id: time_control_preset.key,
        category: time_control_preset.category,
        clock_type: time_control_preset.clock_type,
        clock_config: time_control_preset.clock_config
      }
    else
      { category: time_control }.compact
    end
  end

  def transition!(from:, to:)
    return if status == to
    return false unless status == from

    update!(status: to)
  end

  def distinct_agents
    return if agent_a_id.blank? || agent_b_id.blank?
    return if agent_a_id != agent_b_id

    errors.add(:agent_b_id, "must be different from agent a")
  end

  def set_initial_state
    self.game_key = "chess" if game_key.blank?
    rules = GameRegistry.fetch!(game_key)
    self.initial_state = rules.starting_state(config: game_config) if initial_state.blank?
    self.current_state = initial_state if current_state.blank?
  rescue GameRegistry::UnknownGame
    # Validation will surface unsupported games.
  end

  def preset_matches_game
    return if time_control_preset.blank?
    return if time_control_preset.game_key == game_key

    errors.add(:time_control_preset_id, "must match game key")
  end

  def rated_preset_allowed
    return unless rated?

    if time_control_preset.blank?
      errors.add(:time_control_preset_id, "is required for rated matches")
      return
    end

    return if time_control_preset.rated_allowed?

    errors.add(:time_control_preset_id, "is not approved for rated games")
  end

  def tournament_constraints
    return if tournament.blank?

    if tournament.game_key != game_key
      errors.add(:game_key, "must match tournament game")
    end

    if tournament.rated != rated
      errors.add(:rated, "must match tournament rated setting")
    end

    return if time_control_preset.blank?
    return if tournament.preset_allowed?(time_control_preset)

    errors.add(:time_control_preset_id, "is not allowed for this tournament")
  end

  def snapshot_agent_model!(agent, role)
    return if MatchAgentModel.exists?(match_id: id, agent_id: agent.id, game_key: game_key)

    model_payload = agent.metadata.fetch("models", {}).fetch(game_key, {})

    match_agent_models.create!(
      agent: agent,
      game_key: game_key,
      role: role,
      provider: model_payload["provider"],
      model_slug: model_payload["model_name"],
      model_version: model_payload["model_version"],
      model_info: model_payload.fetch("model_info", {})
    )
  end

  def next_actor
    GameRegistry.fetch!(game_key).actor_for_ply(ply_count)
  end

  def assign_default_rated_time_control_preset
    return unless rated?
    return if time_control_preset.present?
    return if game_key.blank?

    scope = TimeControlPreset.active.where(game_key: game_key, rated_allowed: true)
    scope = scope.where(category: time_control) if time_control.present?

    if tournament.present?
      if tournament.locked_time_control_preset_id.present?
        scope = scope.where(id: tournament.locked_time_control_preset_id)
      elsif tournament.tournament_time_control_presets.exists?
        scope = scope.where(id: tournament.allowed_time_control_presets.select(:id))
      end
    end

    self.time_control_preset = scope.order(:key).first
    self.time_control = time_control_preset.category if time_control_preset.present? && time_control.blank?
  end

  def default_tags
    {
      event: "Tournaiment Match",
      site: "Tournaiment",
      date: created_at || Time.current,
      round: "1",
      white: agent_a&.name || "White",
      black: agent_b&.name || "Black"
    }
  end

  def finished_tournament_match?
    saved_change_to_status? && status == "finished" && tournament_pairing_id.present?
  end

  def schedule_tournament_progress!
    TournamentProgressJob.perform_later(id)
  end
end
