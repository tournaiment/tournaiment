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

    @games = GameRegistry.supported_keys
  end

  def h2h
    @game_key = params[:game].presence || GameRegistry.supported_keys.first

    @agent_options = Agent.order(:name).pluck(:id, :name)
      .map { |id, name| { id: id, name: name } }

    @agent_a_id = params[:agent_a].presence || @agent_options.first&.fetch(:id)
    @agent_b_id = params[:agent_b].presence || @agent_options.second&.fetch(:id) || @agent_a_id

    @agent_a = Agent.find_by(id: @agent_a_id)
    @agent_b = Agent.find_by(id: @agent_b_id)

    matches = Match.where(status: "finished", game_key: @game_key)
      .includes(:match_agent_models, :white_agent, :black_agent)

    @h2h_summary, @match_rows = summarize_agent_h2h(matches, @agent_a, @agent_b)
    @chart_a = rating_series_for_agent(@agent_a, @game_key)
    @chart_b = rating_series_for_agent(@agent_b, @game_key)
    @model_usage_a = model_usage_for_agent(@match_rows, @agent_a)
    @model_usage_b = model_usage_for_agent(@match_rows, @agent_b)

    @games = GameRegistry.supported_keys
  end

  private

  def label_from(provider, model_name, model_version)
    provider = provider.presence || "unknown"
    model_name = model_name.presence || "unknown"
    model_version = model_version.presence || "unknown"
    "#{provider} #{model_name} #{model_version}"
  end

  def summarize_agent_h2h(matches, agent_a, agent_b)
    summary = { wins_a: 0, wins_b: 0, draws: 0, total: 0 }
    rows = []

    return [summary, rows] if agent_a.nil? || agent_b.nil?

    matches.find_each do |match|
      next unless [match.white_agent_id, match.black_agent_id].sort == [agent_a.id, agent_b.id].sort

      entries = match.match_agent_models.select { |entry| entry.game_key == match.game_key }
      white_model = entries.find { |entry| entry.role == "white" }
      black_model = entries.find { |entry| entry.role == "black" }

      summary[:total] += 1
      case match.result
      when "1-0"
        match.white_agent_id == agent_a.id ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      when "0-1"
        match.black_agent_id == agent_a.id ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      when "1/2-1/2"
        summary[:draws] += 1
      else
        summary[:total] -= 1
      end

      rows << {
        match_id: match.id,
        result: match.result,
        finished_at: match.finished_at,
        white_agent: match.white_agent,
        black_agent: match.black_agent,
        white_model: white_model,
        black_model: black_model,
        white_model_label: white_model ? label_from(white_model.provider, white_model.model_name, white_model.model_version) : "unknown unknown unknown",
        black_model_label: black_model ? label_from(black_model.provider, black_model.model_name, black_model.model_version) : "unknown unknown unknown"
      }
    end

    [summary, rows]
  end

  def rating_series_for_agent(agent, game_key)
    return [] if agent.nil?

    RatingChange.joins("INNER JOIN matches ON matches.id = rating_changes.match_id")
      .where(matches: { status: "finished", game_key: game_key })
      .where(rating_changes: { agent_id: agent.id })
      .order("rating_changes.created_at ASC")
      .pluck("rating_changes.created_at", "rating_changes.after_rating")
      .map { |timestamp, rating| { date: timestamp.to_date.to_s, value: rating.to_f } }
  end

  def model_usage_for_agent(rows, agent)
    usage = Hash.new(0)
    rows.each do |row|
      label = row[:white_agent]&.id == agent&.id ? row[:white_model_label] : row[:black_model_label]
      usage[label] += 1
    end
    usage.sort_by { |_, count| -count }.map { |label, count| { label: label, count: count } }
  end
end
