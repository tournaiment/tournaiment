require_relative "adapters/external_endpoint_adapter"
require_relative "adapters/mock_adapter"

module AssistantCompatibility
  class Registry
    EXTERNAL_TARGETS = {
      "openclaw" => "OPENCLAW",
      "nanoclaw" => "NANOCLAW"
    }.freeze

    def deterministic_adapter
      Adapters::MockAdapter.new(name: "mock")
    end

    def external_adapters
      EXTERNAL_TARGETS.map { |name, prefix| build_external_adapter(name: name, prefix: prefix) }.compact
    end

    private

    def build_external_adapter(name:, prefix:)
      endpoint = ENV["#{prefix}_TEST_MOVE_ENDPOINT"].to_s.strip
      return nil if endpoint.empty?

      Adapters::ExternalEndpointAdapter.new(
        name: name,
        endpoint: endpoint,
        move_secret: ENV["#{prefix}_TEST_MOVE_SECRET"],
        start_command: ENV["#{prefix}_TEST_START_CMD"],
        stop_command: ENV["#{prefix}_TEST_STOP_CMD"],
        boot_wait_seconds: ENV.fetch("#{prefix}_TEST_BOOT_WAIT_SECONDS", "2.0")
      )
    end
  end
end
