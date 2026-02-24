require "ipaddr"

class AgentEndpointPolicy
  class InvalidEndpoint < StandardError; end

  LOCAL_HOSTS = %w[
    localhost
    localhost.localdomain
  ].freeze

  LOCAL_SUFFIXES = %w[
    .localhost
    .local
    .internal
    .home.arpa
  ].freeze

  class << self
    def validate_move_endpoint!(value)
      validate!(value, kind: "move")
    end

    def validate_tournament_endpoint!(value)
      validate!(value, kind: "tournament")
    end

    def validate!(value, kind:)
      endpoint = value.to_s.strip
      raise InvalidEndpoint, "Agent #{kind} endpoint missing" if endpoint.empty?

      uri = URI.parse(endpoint)
      unless uri.is_a?(URI::HTTP)
        raise InvalidEndpoint, "Agent #{kind} endpoint must use http or https"
      end

      scheme = uri.scheme.to_s.downcase
      host = uri.host.to_s.strip
      raise InvalidEndpoint, "Agent #{kind} endpoint host missing" if host.empty?

      unless %w[http https].include?(scheme)
        raise InvalidEndpoint, "Agent #{kind} endpoint must use http or https"
      end

      if scheme == "http" && !allow_insecure_http?
        raise InvalidEndpoint, "Agent #{kind} endpoint must use https"
      end

      return uri if allow_private_network_endpoints?
      raise InvalidEndpoint, "Agent #{kind} endpoint host is not allowed" if local_hostname?(host) || non_public_ip?(host)

      uri
    rescue URI::InvalidURIError
      raise InvalidEndpoint, "Agent #{kind} endpoint is invalid"
    end

    def allow_insecure_http?
      Rails.env.development? || Rails.env.test? || ENV["ALLOW_INSECURE_AGENT_HTTP"] == "1"
    end

    def allow_private_network_endpoints?
      !Rails.env.production? || ENV["ALLOW_PRIVATE_AGENT_ENDPOINTS"] == "1"
    end

    private

    def local_hostname?(host)
      normalized = host.to_s.downcase
      return true if LOCAL_HOSTS.include?(normalized)

      LOCAL_SUFFIXES.any? { |suffix| normalized.end_with?(suffix) }
    end

    def non_public_ip?(host)
      ip = IPAddr.new(host)
      ip.private? || ip.loopback? || ip.link_local? || ip.multicast? || ip.unspecified?
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
