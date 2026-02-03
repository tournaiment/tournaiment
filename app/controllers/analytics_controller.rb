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
        record.model_slug.presence || "unknown",
        record.model_version.presence || "unknown"
      ]
    end

    @model_stats = grouped.map do |(game_key, provider, model_slug, model_version), entries|
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
        model_slug: model_slug,
        model_version: model_version,
        wins: stats[:wins],
        losses: stats[:losses],
        draws: stats[:draws],
        total: stats[:total],
        win_rate: stats[:total].positive? ? (stats[:wins].to_f / stats[:total]) : 0.0,
        avg_rating: avg_rating
      }
    end.sort_by { |row| [-row[:win_rate], -row[:total]] }

    @games = GameRegistry.supported_keys
  end

  def h2h
    @game_key = params[:game].presence || GameRegistry.supported_keys.first

    @model_options = MatchAgentModel.where(game_key: @game_key)
      .distinct
      .order(:provider, :model_slug, :model_version)
      .pluck(:provider, :model_slug, :model_version)
      .map { |provider, model_slug, model_version| build_model_option(provider, model_slug, model_version) }

    @comparison_requested = params[:a_model].present?

    if @model_options.any?
      a_raw = parse_model_param(params[:a_model])
      b_raw = parse_model_param(params[:b_model])

      a_raw ||= @model_options.first || default_model_option
      b_raw ||= @model_options.second || @model_options.first || default_model_option

      @model_a = a_raw.merge(label: model_label(a_raw))
      @model_b = b_raw.merge(label: model_label(b_raw))
    end

    if @comparison_requested && @model_a && @model_b
      matches = Match.where(status: "finished", game_key: @game_key)
        .includes(:match_agent_models)

      @h2h_summary = summarize_h2h(matches, @model_a, @model_b)
      @chart_a = rating_series(@model_a, @game_key)
      @chart_b = rating_series(@model_b, @game_key)
    else
      @h2h_summary = { wins_a: 0, wins_b: 0, draws: 0, total: 0 }
      @chart_a = []
      @chart_b = []
    end

    @games = GameRegistry.supported_keys
  end

  private

  def build_model_option(provider, model_slug, model_version)
    {
      provider: provider.presence || "unknown",
      model_slug: model_slug.presence || "unknown",
      model_version: model_version.presence || "unknown",
      label: model_label(provider: provider, model_slug: model_slug, model_version: model_version),
      value: [provider.presence || "unknown", model_slug.presence || "unknown", model_version.presence || "unknown"].join("|")
    }
  end

  def parse_model_param(value)
    return nil if value.blank?

    provider, model_slug, model_version = value.split("|", 3)
    {
      provider: provider,
      model_slug: model_slug,
      model_version: model_version
    }
  end

  def default_model_option
    { provider: "unknown", model_slug: "unknown", model_version: "unknown" }
  end

  def model_label(model)
    provider = model[:provider].presence || "unknown"
    model_slug = model[:model_slug].presence || "unknown"
    model_version = model[:model_version].presence || "unknown"
    label_from(provider, model_slug, model_version)
  end

  def label_from(provider, model_slug, model_version)
    provider = provider.presence || "unknown"
    model_slug = model_slug.presence || "unknown"
    model_version = model_version.presence || "unknown"
    "#{provider} #{model_slug} #{model_version}"
  end

  def summarize_h2h(matches, model_a, model_b)
    summary = { wins_a: 0, wins_b: 0, draws: 0, total: 0 }

    matches.find_each do |match|
      entries = match.match_agent_models.select { |entry| entry.game_key == match.game_key }
      white = entries.find { |entry| entry.role == "white" }
      black = entries.find { |entry| entry.role == "black" }
      next unless white && black

      white_key = label_from(white.provider, white.model_slug, white.model_version)
      black_key = label_from(black.provider, black.model_slug, black.model_version)
      pair = [white_key, black_key].sort
      target = [model_a[:label], model_b[:label]].sort
      next unless pair == target

      summary[:total] += 1
      case match.result
      when "1-0"
        white_key == model_a[:label] ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      when "0-1"
        black_key == model_a[:label] ? summary[:wins_a] += 1 : summary[:wins_b] += 1
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
      .where(match_agent_models: {
        provider: model[:provider] == "unknown" ? nil : model[:provider],
        model_slug: model[:model_slug] == "unknown" ? nil : model[:model_slug],
        model_version: model[:model_version] == "unknown" ? nil : model[:model_version]
      })
      .order("rating_changes.created_at ASC")
      .pluck("rating_changes.created_at", "rating_changes.after_rating")

    changes.map do |timestamp, rating|
      { date: timestamp.to_date.to_s, value: rating.to_f }
    end
  end
end
