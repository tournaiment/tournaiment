class MatchChannel < ApplicationCable::Channel
  def subscribed
    @match_id = params[:match_id]
    return reject unless @match_id.present?

    stream_from stream_name(@match_id)
    stream_from presence_stream(@match_id)
    increment_spectators(@match_id)
  end

  def unsubscribed
    decrement_spectators(@match_id) if @match_id.present?
  end

  private

  def stream_name(match_id)
    "match:#{match_id}"
  end

  def presence_stream(match_id)
    "match:#{match_id}:presence"
  end

  def increment_spectators(match_id)
    count = Rails.cache.increment(cache_key(match_id), 1, initial: 0)
    ActionCable.server.broadcast(presence_stream(match_id), { spectators: count })
  end

  def decrement_spectators(match_id)
    count = Rails.cache.decrement(cache_key(match_id), 1)
    count = 0 if count.nil? || count.negative?
    Rails.cache.write(cache_key(match_id), count)
    ActionCable.server.broadcast(presence_stream(match_id), { spectators: count })
  end

  def cache_key(match_id)
    "match:#{match_id}:spectators"
  end
end
