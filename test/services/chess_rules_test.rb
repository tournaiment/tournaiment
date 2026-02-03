require "test_helper"

class ChessRulesTest < ActiveSupport::TestCase
  test "starting state is standard" do
    assert_equal ChessRules::STARTING_FEN, ChessRules.starting_state
  end

  test "apply_move updates fen and produces san" do
    data = ChessRules.apply_move(state: ChessRules::STARTING_FEN, move: "e2e4", actor: "white")

    assert_equal "e4", data[:display]
    assert data[:state].present?
    assert data.key?(:result)
  end
end
