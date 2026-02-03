class Match < ApplicationRecord
  STARTING_FEN = ChessRules::STARTING_FEN
  STATUSES = %w[created queued running finished cancelled failed invalid].freeze

  belongs_to :white_agent, class_name: "Agent", optional: true
  belongs_to :black_agent, class_name: "Agent", optional: true
  has_many :moves, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :white_agent_id, presence: true
  validate :distinct_agents
  validates :current_fen, presence: true
  validates :initial_fen, presence: true

  before_validation :set_initial_fen, on: :create

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

  def record_uci_move!(uci)
    raise ArgumentError, "Match is not running" unless status == "running"

    update!(started_at: Time.current) if started_at.nil?

    data = ChessRules.apply_uci!(fen: current_fen, uci: uci)
    next_ply = ply_count + 1
    move_number = (next_ply + 1) / 2
    color = next_ply.odd? ? "white" : "black"

    moves.create!(
      ply: next_ply,
      move_number: move_number,
      color: color,
      uci: uci,
      san: data[:san],
      fen: data[:fen],
      created_at: Time.current
    )

    update!(
      current_fen: data[:fen],
      ply_count: next_ply,
      result: (data[:result] == "*" ? nil : data[:result])
    )
  end

  def generate_pgn!
    ordered_moves = moves.order(:ply).pluck(:san)
    self.pgn = ChessRules.build_pgn(
      moves: ordered_moves,
      result: result,
      tags: {
        event: "Tournaiment Match",
        site: "Tournaiment",
        date: created_at || Time.current,
        round: "1",
        white: white_agent&.name || "White",
        black: black_agent&.name || "Black"
      }
    )
    save!
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

  def set_initial_fen
    self.initial_fen = STARTING_FEN if initial_fen.blank?
    self.current_fen = STARTING_FEN if current_fen.blank?
  end
end
