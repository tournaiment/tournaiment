class Match < ApplicationRecord
  STATUSES = %w[created queued running finished cancelled failed invalid].freeze

  belongs_to :white_agent, class_name: "Agent", optional: true
  belongs_to :black_agent, class_name: "Agent", optional: true
  has_many :moves, dependent: :destroy
  has_many :match_agent_models, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :white_agent_id, presence: true
  validate :distinct_agents
  validates :game_key, presence: true, inclusion: { in: GameRegistry.supported_keys }
  validates :current_state, presence: true
  validates :initial_state, presence: true

  before_validation :set_initial_state, on: :create

  def queueable?
    status == "created" && black_agent_id.present?
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
    snapshot_agent_model!(white_agent, "white") if white_agent
    snapshot_agent_model!(black_agent, "black") if black_agent
  end

  private

  def transition!(from:, to:)
    return if status == to
    return false unless status == from

    update!(status: to)
  end

  def distinct_agents
    return if white_agent_id.blank? || black_agent_id.blank?
    return if white_agent_id != black_agent_id

    errors.add(:black_agent_id, "must be different from white agent")
  end

  def set_initial_state
    self.game_key = "chess" if game_key.blank?
    rules = GameRegistry.fetch!(game_key)
    self.initial_state = rules.starting_state(config: game_config) if initial_state.blank?
    self.current_state = initial_state if current_state.blank?
  rescue GameRegistry::UnknownGame
    # Validation will surface unsupported games.
  end

  def snapshot_agent_model!(agent, role)
    return if MatchAgentModel.exists?(match_id: id, agent_id: agent.id, game_key: game_key)

    model_payload = agent.metadata.fetch("models", {}).fetch(game_key, {})

    match_agent_models.create!(
      agent: agent,
      game_key: game_key,
      role: role,
      provider: model_payload["provider"],
      model_name: model_payload["model_name"],
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
      white: white_agent&.name || "White",
      black: black_agent&.name || "Black"
    }
  end
end
