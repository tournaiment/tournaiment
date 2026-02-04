class Match < ApplicationRecord
  STATUSES = %w[created queued running finished cancelled failed invalid].freeze

  belongs_to :agent_a, class_name: "Agent", optional: true
  belongs_to :agent_b, class_name: "Agent", optional: true
  has_many :moves, dependent: :destroy
  has_many :match_agent_models, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :agent_a_id, presence: true
  validate :distinct_agents
  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :current_state, presence: true
  validates :initial_state, presence: true

  before_validation :set_initial_state, on: :create

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

  def snapshot_agent_models!
    snapshot_agent_model!(agent_a, "a") if agent_a
    snapshot_agent_model!(agent_b, "b") if agent_b
  end

  private

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
end
