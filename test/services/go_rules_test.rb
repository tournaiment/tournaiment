require "test_helper"

class GoRulesTest < ActiveSupport::TestCase
  def build_state(overrides = {})
    base = {
      "ruleset" => "chinese",
      "size" => 9,
      "komi" => 7.5,
      "board" => "." * 81,
      "to_move" => "black",
      "ko" => nil,
      "passes" => 0,
      "captures" => { "black" => 0, "white" => 0 }
    }
    JSON.generate(base.merge(overrides))
  end

  def set_stone(board, coord, color)
    idx = GoRules.coord_to_index(coord, 9)
    board[idx] = color
  end

  test "starting state uses defaults" do
    state = JSON.parse(GoRules.starting_state(config: { "ruleset" => "chinese", "board_size" => 19 }))
    assert_equal "chinese", state["ruleset"]
    assert_equal 19, state["size"]
    assert_equal 7.5, state["komi"]
    assert_equal "black", state["to_move"]
    assert_equal 0, state["passes"]
    assert_equal({ "black" => 0, "white" => 0 }, state["captures"])
  end

  test "capture increments captures and removes stones" do
    board = Array.new(81, ".")
    set_stone(board, "C4", "b")
    set_stone(board, "D3", "b")
    set_stone(board, "E4", "b")
    set_stone(board, "D4", "w")

    state = build_state(
      "board" => board.join,
      "to_move" => "black"
    )

    result = GoRules.apply_move(state: state, move: "D5", actor: "black")
    data = JSON.parse(result[:state])

    assert_equal "b", data["board"][GoRules.coord_to_index("D5", 9)]
    assert_equal ".", data["board"][GoRules.coord_to_index("D4", 9)]
    assert_equal 1, data["captures"]["black"]
  end

  test "two passes ends the game with chinese scoring" do
    state = build_state("passes" => 1, "komi" => 0.0, "to_move" => "black")
    result = GoRules.apply_move(state: state, move: "pass", actor: "black")

    assert_equal "finished", result[:status]
    assert_equal "1/2-1/2", result[:result]
  end

  test "japanese scoring uses captures" do
    state = build_state(
      "ruleset" => "japanese",
      "passes" => 1,
      "komi" => 0.0,
      "captures" => { "black" => 2, "white" => 0 },
      "to_move" => "black"
    )

    result = GoRules.apply_move(state: state, move: "pass", actor: "black")
    assert_equal "0-1", result[:result]
  end

  test "invalid state captures raises error" do
    bad_state = JSON.generate({ "size" => 9, "board" => "." * 81, "to_move" => "black" })
    assert_raises(GoRules::IllegalMove) do
      GoRules.apply_move(state: bad_state, move: "pass", actor: "black")
    end
  end
end
