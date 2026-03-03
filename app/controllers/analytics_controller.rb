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

    all_model_stats = grouped.map do |(game_key, provider, model_name, model_version), entries|
      stats = { wins: 0, losses: 0, draws: 0, total: 0 }

      entries.each do |entry|
        stats[:total] += 1
        match = entry.match
        result = match&.result
        entry_side = normalize_match_side(entry.role)

        case result
        when "1/2-1/2"
          stats[:draws] += 1
        when "1-0", "0-1"
          winner_side = match_winner_side(match)
          if winner_side.present?
            entry_side == winner_side ? stats[:wins] += 1 : stats[:losses] += 1
          else
            legacy_winner_side = result == "1-0" ? "a" : "b"
            entry_side == legacy_winner_side ? stats[:wins] += 1 : stats[:losses] += 1
          end
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
    end.sort_by { |row| [ -row[:win_rate], -row[:total] ] }
    @model_stats, @model_stats_pagination = paginate_array(all_model_stats, default_per_page: 30, max_per_page: 200)

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
      .includes(:match_agent_models, :agent_a, :agent_b)

    @h2h_summary, match_rows = summarize_agent_h2h(matches, @agent_a, @agent_b)
    @chart_a = rating_series_for_agent(@agent_a, @game_key)
    @chart_b = rating_series_for_agent(@agent_b, @game_key)
    @model_usage_a = model_usage_for_agent(match_rows, @agent_a)
    @model_usage_b = model_usage_for_agent(match_rows, @agent_b)
    sorted_rows = match_rows.sort_by { |row| row[:finished_at] || Time.at(0) }.reverse
    @match_rows, @match_rows_pagination = paginate_array(sorted_rows, default_per_page: 30, max_per_page: 200)

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

    return [ summary, rows ] if agent_a.nil? || agent_b.nil?

    matches.find_each do |match|
      next unless [ match.agent_a_id, match.agent_b_id ].sort == [ agent_a.id, agent_b.id ].sort

      entries = match.match_agent_models.select { |entry| entry.game_key == match.game_key }
      white_model = entries.find { |entry| entry.role == "a" || entry.role == "white" }
      black_model = entries.find { |entry| entry.role == "b" || entry.role == "black" }

      summary[:total] += 1
      if match.result == "1/2-1/2"
        summary[:draws] += 1
      elsif match_winner_side(match).present?
        winner_agent_id = match_winner_side(match) == "a" ? match.agent_a_id : match.agent_b_id
        winner_agent_id == agent_a.id ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      elsif match.result == "1-0" || match.result == "0-1"
        legacy_winner_agent_id = match.result == "1-0" ? match.agent_a_id : match.agent_b_id
        legacy_winner_agent_id == agent_a.id ? summary[:wins_a] += 1 : summary[:wins_b] += 1
      else
        summary[:total] -= 1
      end

      rows << {
        match_id: match.id,
        result: match.result,
        finished_at: match.finished_at,
        agent_a: match.agent_a,
        agent_b: match.agent_b,
        model_a: white_model,
        model_b: black_model,
        model_a_label: white_model ? label_from(white_model.provider, white_model.model_slug, white_model.model_version) : "unknown unknown unknown",
        model_b_label: black_model ? label_from(black_model.provider, black_model.model_slug, black_model.model_version) : "unknown unknown unknown"
      }
    end

    [ summary, rows ]
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
      label = row[:agent_a]&.id == agent&.id ? row[:model_a_label] : row[:model_b_label]
      usage[label] += 1
    end
    usage.sort_by { |_, count| -count }.map { |label, count| { label: label, count: count } }
  end

  def normalize_match_side(value)
    side = value.to_s
    return "a" if side == "a" || side == "white"
    return "b" if side == "b" || side == "black"

    nil
  end

  def match_winner_side(match)
    normalize_match_side(match&.winner_side)
  end
end
