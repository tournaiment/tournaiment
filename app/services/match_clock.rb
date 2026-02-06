class MatchClock
  DEFAULT_INCREMENT_BY_CATEGORY = {
    "bullet" => { base_seconds: 60, increment_seconds: 0 },
    "blitz" => { base_seconds: 180, increment_seconds: 2 },
    "rapid" => { base_seconds: 600, increment_seconds: 0 },
    "classical" => { base_seconds: 1800, increment_seconds: 0 }
  }.freeze

  def initialize(match)
    @match = match
    @rules = GameRegistry.fetch!(@match.game_key)
  end

  def ensure_initialized!
    return if @match.clock_state.present?

    state = if preset_clock_type == "byoyomi"
              build_byoyomi_state
    else
              build_increment_state
    end
    @match.update!(clock_state: state)
  end

  def time_remaining_seconds(actor)
    state = @match.clock_state
    return 0 if state.blank?

    if state["clock_type"] == "byoyomi"
      main = state.dig("main_time_seconds", actor).to_f
      period = state["period_time_seconds"].to_f
      periods_left = state.dig("periods_left", actor).to_i
      main.positive? ? main : (period * periods_left)
    else
      state.dig("remaining_seconds", actor).to_f
    end
  end

  def actor_state(actor)
    state = @match.clock_state
    return {} if state.blank?

    if state["clock_type"] == "byoyomi"
      {
        actor: actor,
        main_time_seconds: state.dig("main_time_seconds", actor).to_f,
        period_time_seconds: state["period_time_seconds"].to_f,
        periods_left: state.dig("periods_left", actor).to_i
      }
    else
      {
        actor: actor,
        remaining_seconds: state.dig("remaining_seconds", actor).to_f,
        increment_seconds: state["increment_seconds"].to_f
      }
    end
  end

  def consume!(actor, elapsed_seconds)
    elapsed = [ elapsed_seconds.to_f, 0.0 ].max
    state = @match.clock_state.deep_dup

    outcome = if state["clock_type"] == "byoyomi"
                consume_byoyomi!(state, actor, elapsed)
    else
                consume_increment!(state, actor, elapsed)
    end

    @match.update!(clock_state: state)
    outcome
  end

  private

  def preset_clock_type
    @match.time_control_preset&.clock_type
  end

  def preset_clock_config
    @match.time_control_preset&.clock_config || {}
  end

  def actors_hash(value)
    @rules.actors.index_with { value }
  end

  def build_increment_state
    config = if preset_clock_type == "increment"
               preset_clock_config
    else
               DEFAULT_INCREMENT_BY_CATEGORY.fetch(@match.time_control.to_s, DEFAULT_INCREMENT_BY_CATEGORY["rapid"])
    end

    base = config["base_seconds"] || config[:base_seconds] || 600
    increment = config["increment_seconds"] || config[:increment_seconds] || 0

    {
      "clock_type" => "increment",
      "remaining_seconds" => actors_hash(base.to_f),
      "increment_seconds" => increment.to_f
    }
  end

  def build_byoyomi_state
    config = preset_clock_config
    main = config["main_time_seconds"] || config[:main_time_seconds] || 600
    period = config["period_time_seconds"] || config[:period_time_seconds] || 30
    periods = config["periods"] || config[:periods] || 5

    {
      "clock_type" => "byoyomi",
      "main_time_seconds" => actors_hash(main.to_f),
      "period_time_seconds" => period.to_f,
      "periods_total" => periods.to_i,
      "periods_left" => actors_hash(periods.to_i)
    }
  end

  def consume_increment!(state, actor, elapsed)
    remaining = state.dig("remaining_seconds", actor).to_f
    remaining -= elapsed
    return :time_loss if remaining <= 0

    remaining += state["increment_seconds"].to_f
    state["remaining_seconds"][actor] = remaining
    :ok
  end

  def consume_byoyomi!(state, actor, elapsed)
    main = state.dig("main_time_seconds", actor).to_f
    period = state["period_time_seconds"].to_f
    periods_left = state.dig("periods_left", actor).to_i

    if main.positive?
      if elapsed <= main
        state["main_time_seconds"][actor] = main - elapsed
        return :ok
      end

      elapsed -= main
      state["main_time_seconds"][actor] = 0.0
    end

    return :ok if elapsed <= period

    periods_used = ((elapsed - period) / period).ceil
    return :time_loss if periods_used >= periods_left

    state["periods_left"][actor] = periods_left - periods_used
    :ok
  end
end
