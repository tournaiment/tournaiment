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
    winner_side = match_winner_side(match)
    return "#{match_side_name(match, winner_side)} wins." if winner_side.present?
    return "Draw." if match.result == "1/2-1/2"

    nil
  end

  def match_result_label(match)
    winner_side = match_winner_side(match)

    if !match.rated?
      return "Exhibition — #{match_side_name(match, winner_side)} wins" if winner_side.present?
      return "Exhibition — Draw" if match.result == "1/2-1/2"
      return "Exhibition — Finished" if match.status == "finished"

      return "Exhibition"
    end

    return "#{match_side_name(match, winner_side)} wins" if winner_side.present?
    return "Draw" if match.result == "1/2-1/2"
    return "Finished" if match.status == "finished"

    "In progress"
  end

  def match_outcome_for_agent(match, agent)
    return nil if agent.nil?

    winner_side = match_winner_side(match)
    return :draw if match.result == "1/2-1/2"
    return nil unless winner_side.present?

    winner_agent_id = winner_side == "a" ? match.agent_a_id : match.agent_b_id
    winner_agent_id == agent.id ? :win : :loss
  end

  def match_winner_side(match)
    normalized = normalize_side(match.winner_side)
    return normalized if %w[a b].include?(normalized)

    legacy_result_winner_side(match.result)
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

  def local_datetime_tag(value, fallback: "TBD")
    return fallback if value.blank?

    utc_time = value.utc
    fallback_label = utc_time.strftime("%b %-d, %Y %-I:%M %p UTC")
    time_tag(
      utc_time,
      fallback_label,
      data: {
        controller: "local-time",
        local_time_iso_value: utc_time.iso8601
      }
    )
  end

  def tournament_datetime_tag(value, time_zone:, fallback: "TBD")
    return fallback if value.blank?

    zone = ActiveSupport::TimeZone[time_zone] || ActiveSupport::TimeZone[Tournament::DEFAULT_TIME_ZONE]
    zoned_time = value.in_time_zone(zone)
    content_tag(:span, "#{zoned_time.strftime('%b %-d, %Y %-I:%M %p')} (#{zone.tzinfo.name})")
  end

  def dual_datetime_display(value, tournament_time_zone:, fallback: "TBD")
    local_value = value.present? ? local_datetime_tag(value, fallback: fallback) : fallback
    tournament_value = value.present? ? tournament_datetime_tag(value, time_zone: tournament_time_zone, fallback: fallback) : fallback

    content_tag(:div, class: "stack") do
      safe_join([
        content_tag(:div) do
          safe_join([
            content_tag(:span, "Your time:", class: "stat-label"),
            " ",
            local_value
          ])
        end,
        content_tag(:div) do
          safe_join([
            content_tag(:span, "Tournament time:", class: "stat-label"),
            " ",
            tournament_value
          ])
        end
      ])
    end
  end

  private

  def legacy_result_winner_side(result)
    return "a" if result == "1-0"
    return "b" if result == "0-1"

    nil
  end
end
