require "net/http"
require "json"
require "openssl"

class TournamentNotificationService
  class DeliveryError < StandardError; end

  TIMEOUT = 5.seconds

  def initialize(tournament:, event:, agent_ids:, payload: {}, raise_on_failure: false)
    @tournament = tournament
    @event = event
    @agent_ids = agent_ids
    @payload = payload
    @raise_on_failure = raise_on_failure
  end

  def call
    Agent.where(id: @agent_ids).find_each do |agent|
      endpoint = agent.metadata["tournament_endpoint"].to_s
      next if endpoint.empty?

      send_notification(agent, endpoint)
    end
  end

  private

  def send_notification(agent, endpoint)
    uri = URI.parse(endpoint)
    timestamp = Time.current.to_i.to_s
    request_payload = {
      event: @event,
      tournament_id: @tournament.id,
      tournament_name: @tournament.name,
      game_key: @tournament.game_key,
      format: @tournament.format,
      payload: @payload
    }
    body = JSON.generate(request_payload)

    response = nil
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["X-Tournaiment-Timestamp"] = timestamp
      signature = signature_for(agent, timestamp, body)
      request["X-Tournaiment-Signature"] = signature if signature.present?
      request.body = body
      response = http.request(request)
    end

    if response.nil? || response.code.to_i >= 400
      raise DeliveryError, "Notification failed with status #{response&.code}"
    end

    AuditLog.log!(
      actor: nil,
      action: "tournament.notified",
      auditable: @tournament,
      metadata: { event: @event, agent_id: agent.id, status: response&.code.to_i }
    )
  rescue StandardError => e
    AuditLog.log!(
      actor: nil,
      action: "tournament.notification_failed",
      auditable: @tournament,
      metadata: { event: @event, agent_id: agent.id, error: e.message }
    )
    raise DeliveryError, e.message if @raise_on_failure
  end

  def signature_for(agent, timestamp, body)
    secret = agent.metadata["tournament_secret"].presence || ENV["TOURNAMENT_WEBHOOK_SECRET"].presence
    return nil if secret.blank?

    OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
  end
end
