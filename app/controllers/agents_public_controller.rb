class AgentsPublicController < ApplicationController
  def show
    @agent = Agent.find_by(id: params[:id]) || Agent.find_by(name: params[:id])
    return head :not_found unless @agent

    @ratings = @agent.ratings.where("games_played > 0")
    @recent_matches = Match.includes(:agent_a, :agent_b)
      .where("agent_a_id = :id OR agent_b_id = :id", id: @agent.id)
      .order(created_at: :desc)
      .limit(20)

    @recent_finished = Match.includes(:agent_a, :agent_b)
      .where(status: "finished")
      .where("agent_a_id = :id OR agent_b_id = :id", id: @agent.id)
      .order(finished_at: :desc)
      .limit(50)

    @stats_by_game = build_stats(@recent_finished)
    @overall_stats = aggregate_stats(@stats_by_game)
    @streak = compute_streak(@recent_finished)
    @last_played = @recent_finished.first&.finished_at
    @models = @agent.metadata.fetch("models", {})
  end

  private

  def build_stats(matches)
    stats = Hash.new { |hash, key| hash[key] = { wins: 0, losses: 0, draws: 0, total: 0, win_rate: 0.0, avg_opponent_rating: nil } }
    opponent_ratings = Hash.new { |hash, key| hash[key] = [] }

    matches.each do |match|
      game = match.game_key
      result = match.result
      role = match.agent_a_id == @agent.id ? "A" : "B"
      opponent = role == "A" ? match.agent_b : match.agent_a

      stats[game][:total] += 1
      case result
      when "1-0"
        role == "A" ? stats[game][:wins] += 1 : stats[game][:losses] += 1
      when "0-1"
        role == "B" ? stats[game][:wins] += 1 : stats[game][:losses] += 1
      when "1/2-1/2"
        stats[game][:draws] += 1
      else
        stats[game][:total] -= 1
      end

      if opponent
        rating = opponent.ratings.find_by(game_key: game)&.current
        opponent_ratings[game] << rating if rating
      end
    end

    stats.each_key do |game|
      total = stats[game][:total]
      stats[game][:win_rate] = total.positive? ? (stats[game][:wins].to_f / total) : 0.0
      ratings = opponent_ratings[game]
      stats[game][:avg_opponent_rating] = ratings.any? ? (ratings.sum.to_f / ratings.length) : nil
    end

    stats
  end

  def aggregate_stats(stats)
    overall = { wins: 0, losses: 0, draws: 0, total: 0, win_rate: 0.0 }
    stats.each_value do |row|
      overall[:wins] += row[:wins]
      overall[:losses] += row[:losses]
      overall[:draws] += row[:draws]
      overall[:total] += row[:total]
    end
    overall[:win_rate] = overall[:total].positive? ? (overall[:wins].to_f / overall[:total]) : 0.0
    overall
  end

  def compute_streak(matches)
    return nil if matches.empty?

    last_result = nil
    count = 0

    matches.each do |match|
      role = match.agent_a_id == @agent.id ? "A" : "B"
      result = case match.result
               when "1-0"
                 role == "A" ? :win : :loss
               when "0-1"
                 role == "B" ? :win : :loss
               when "1/2-1/2"
                 :draw
               else
                 :other
               end
      break if result == :other

      last_result ||= result
      break if result != last_result

      count += 1
    end

    return nil if last_result.nil?

    { type: last_result, count: count }
  end
end
