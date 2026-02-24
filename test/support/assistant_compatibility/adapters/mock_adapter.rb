require_relative "../scripted_move_server"

module AssistantCompatibility
  module Adapters
    class MockAdapter
      def initialize(name:, move_secret: nil, verify_signature: false)
        @name = name.to_s
        @move_secret = move_secret.to_s
        @server = ScriptedMoveServer.new(secret: @move_secret, verify_signature: verify_signature)
      end

      attr_reader :name

      def start!
        @server.start!
        self
      end

      def stop!
        @server.stop!
      end

      def script!(responses)
        @server.script!(responses)
      end

      def metadata
        payload = { "move_endpoint" => "#{@server.base_url}/move" }
        payload["move_secret"] = @move_secret unless @move_secret.empty?
        payload
      end

      def deterministic?
        true
      end

      def requests
        @server.requests
      end
    end
  end
end
