class AnalyticsController < ApplicationController
  def index
    finished_matches = Match.where(status: "finished")
    @game_filter = params[:game].presence
    finished_matches = finished_matches.where(game_key: @game_filter) if @game_filter.present?

    @game_stats = finished_matches.group(:game_key).count.transform_values do |count|
      { total: count }
    end

    draw_counts = finished_matches.where(result: "1/2-1/2").group(:game_key).count
    @game_stats.each_key do |game_key|
      @game_stats[game_key][:draws] = draw_counts[game_key] || 0
    end

    records = MatchAgentModel.includes(:match)
      .where(matches: { status: "finished" })
    records = records.where(game_key: @game_filter) if @game_filter.present?

    grouped = records.group_by do |record|
      [
        record.game_key,
        record.provider.presence || "unknown",
        record.model_name.presence || "unknown",
        record.model_version.presence || "unknown"
      ]
    end

    @model_stats = grouped.map do |(game_key, provider, model_name, model_version), entries|
      stats = { wins: 0, losses: 0, draws: 0, total: 0 }

      entries.each do |entry|
        stats[:total] += 1
        result = entry.match&.result
        role = entry.role

        case result
        when "1-0"
          role == "white" ? stats[:wins] += 1 : stats[:losses] += 1
        when "0-1"
          role == "black" ? stats[:wins] += 1 : stats[:losses] += 1
        when "1/2-1/2"
          stats[:draws] += 1
        else
          stats[:total] -= 1
        end
      end

      agent_ids = entries.map(&:agent_id).uniq
      rating_scope = Rating.where(agent_id: agent_ids, game_key: game_key)
      avg_rating = rating_scope.average(:current)&.to_f

      {
        game_key: game_key,
        provider: provider,
        model_name: model_name,
        model_version: model_version,
        wins: stats[:wins],
        losses: stats[:losses],
        draws: stats[:draws],
        total: stats[:total],
        win_rate: stats[:total].positive? ? (stats[:wins].to_f / stats[:total]) : 0.0,
        avg_rating: avg_rating
      }
    end.sort_by { |row| [-row[:win_rate], -row[:total]] }

    h2h_filter_matches = finished_matches
    @h2h_stats = build_h2h_stats(h2h_filter_matches)
    @games = GameRegistry.supported_keys
  end

  def h2h
    @game_key = params[:game].presence
    a_raw = extract_model_params("a")
    b_raw = extract_model_params("b")

    raise ActiveRecord::RecordNotFound if @game_key.blank? || a_raw[:provider].blank? || a_raw[:model_name].blank? || a_raw[:model_version].blank?
    raise ActiveRecord::RecordNotFound if b_raw[:provider].blank? || b_raw[:model_name].blank? || b_raw[:model_version].blank?

    a = normalize_model_params(a_raw)
    b = normalize_model_params(b_raw)

    @model_a = a.merge(label: model_label(a_raw))
    @model_b = b.merge(label: model_label(b_raw))

    matches = Match.where(status: "finished", game_key: @game_key)
      .includes(:match_agent_models)

    @h2h_summary = summarize_h2h(matches, @model_a, @model_b)
    @chart_a = rating_series(@model_a, @game_key)
    @chart_b = rating_series(@model_b, @game_key)
  end

  private

  def build_h2h_stats(matches)
    table = Hash.new { |hash, key| hash[key] = { wins_a: 0, wins_b: 0, draws: 0, total: 0 } }

    matches.includes(:match_agent_models).find_each do |match|
      entries = match.match_agent_models.select { |entry| entry.game_key == match.game_key }
      white = entries.find { |entry| entry.role == "white" }
      black = entries.find { |entry| entry.role == "black" }
      next unless white && black

      white_key = model_key(white)
      black_key = model_key(black)
      a, b = [white_key, black_key].sort_by { |item| item[:label] }

      key = [match.game_key, a, b]
      stats = table[key]
      stats[:total] += 1

      case match.result
      when "1-0"
        winner_key = white_key
      when "0-1"
        winner_key = black_key
      when "1/2-1/2"
        stats[:draws] += 1
        next
      else
        stats[:total] -= 1
        next
      end

      if winner_key == a
        stats[:wins_a] += 1
      else
        stats[:wins_b] += 1
      end
    end

    table.map do |(game_key, a, b), stats|
      {
        game_key: game_key,
        model_a: a,
        model_b: b,
        wins_a: stats[:wins_a],
        wins_b: stats[:wins_b],
        draws: stats[:draws],
        total: stats[:total]
      }
    end.sort_by { |row| -row[:total] }
  end

  def model_key(entry)
    provider = entry.provider.presence || "unknown"
    model_name = entry.model_name.presence || "unknown"
    model_version = entry.model_version.presence || "unknown"
    {
      provider: provider,
      model_name: model_name,
      model_version: model_version,
      label: "#{provider} #{model_name} #{model_version}"
    }
  end

  def extract_model_params(prefix)
    {
      provider: params["#{prefix}_provider"],
      model_name: params["#{prefix}_name"],
      model_version: params["#{prefix}_version"]
    }
  end

  def normalize_model_params(model)
    model.transform_values do |value|
      value == "unknown" ? nil : value
    end
  end

  def model_label(model)
    provider = model[:provider].presence || "unknown"
    model_name = model[:model_name].presence || "unknown"
    model_version = model[:model_version].presence || "unknown"
    "#{provider} #{model_name} #{model_version}"
  end

  def summarize_h2h(matches, model_a, model_b)
    summary = { wins_a: 0, wins_b: 0, draws: 0, total: 0 }

    matches.find_each do |match|
      entries = match.match_agent_models.select { |entry| entry.game_key == match.game_key }
      white = entries.find { |entry| entry.role == "white" }
      black = entries.find { |entry| entry.role == "black" }
      next unless white && black

      white_key = model_key(white)
      black_key = model_key(black)
      pair = [white_key[:label], black_key[:label]].sort
      target = [model_a[:label], model_b[:label]].sort
      next unless pair == target

      summary[:total] += 1
      case match.result
      when "1-0"
        white_key[:label] == model_a[:label] ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      when "0-1"
        black_key[:label] == model_a[:label] ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      when "1/2-1/2"
        summary[:draws] += 1
      else
        summary[:total] -= 1
      end
    end

    summary
  end

  def rating_series(model, game_key)
    changes = RatingChange.joins("INNER JOIN matches ON matches.id = rating_changes.match_id")
      .joins("INNER JOIN match_agent_models ON match_agent_models.match_id = rating_changes.match_id AND match_agent_models.agent_id = rating_changes.agent_id AND match_agent_models.game_key = matches.game_key")
      .where(matches: { status: "finished", game_key: game_key })

    changes = if model[:provider].nil?
      changes.where(match_agent_models: { provider: nil })
    else
      changes.where(match_agent_models: { provider: model[:provider] })
    end

    changes = if model[:model_name].nil?
      changes.where(match_agent_models: { model_name: nil })
    else
      changes.where(match_agent_models: { model_name: model[:model_name] })
    end

    changes = if model[:model_version].nil?
      changes.where(match_agent_models: { model_version: nil })
    else
      changes.where(match_agent_models: { model_version: model[:model_version] })
    end

    changes = changes
      .order("rating_changes.created_at ASC")
      .pluck("rating_changes.created_at", "rating_changes.after_rating")

    changes.map do |timestamp, rating|
      { date: timestamp.to_date.to_s, value: rating.to_f }
    end
  end
end
