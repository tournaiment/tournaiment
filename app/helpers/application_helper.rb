module ApplicationHelper
  def match_commentary(match)
    status = match.status.to_s

    return "Awaiting start." if status == "created" || status == "queued"
    return "Live match in progress." if status == "running"
    return "Match cancelled. Result discarded." if status == "cancelled"
    return "Match invalidated. Result rolled back." if status == "invalid"
    return "Match failed." if status == "failed"

    parts = []
    if match.resigned_by_side.present?
      parts << "#{match_side_name(match, match.resigned_by_side)} resigns."
    elsif match.forfeit_by_side.present?
      parts << "#{match_side_name(match, match.forfeit_by_side)} forfeits."
    elsif match.draw_reason.present?
      parts << "Draw by #{match.draw_reason.to_s.humanize}."
    elsif match.winner_side.present?
      parts << "#{match_side_name(match, match.winner_side)} wins."
    elsif match.result.present? && match.result != "*"
      result_phrase = match_result_phrase(match)
      parts << result_phrase if result_phrase.present?
    else
      parts << "Match finished."
    end

    parts << "Result: #{match.result}." if match.result.present? && match.result != "*"
    parts.join(" ")
  end

  def match_context_label(match)
    return "Tournament: #{match.tournament.name}" if match.tournament.present?

    "Exhibition Match"
  end

  def match_result_phrase(match)
    case match.result
    when "1-0"
      "#{match_side_name(match, "a")} wins."
    when "0-1"
      "#{match_side_name(match, "b")} wins."
    when "1/2-1/2"
      "Draw."
    else
      nil
    end
  end

  def match_side_name(match, side)
    normalized = normalize_side(side)
    if normalized == "a"
      match.agent_a&.name || "Opponent A"
    elsif normalized == "b"
      match.agent_b&.name || "Opponent B"
    else
      "Winner"
    end
  end

  def normalize_side(side)
    value = side.to_s
    return "a" if value == "a" || value == "white"
    return "b" if value == "b" || value == "black"
    value
  end
end
