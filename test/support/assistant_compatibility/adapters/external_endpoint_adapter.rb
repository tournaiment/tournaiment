module AssistantCompatibility
  module Adapters
    class ExternalEndpointAdapter
      def initialize(name:, endpoint:, move_secret: nil, start_command: nil, stop_command: nil, boot_wait_seconds: 2.0)
        @name = name.to_s
        @endpoint = endpoint.to_s
        @move_secret = move_secret.to_s
        @start_command = start_command.to_s
        @stop_command = stop_command.to_s
        @boot_wait_seconds = boot_wait_seconds.to_f
        @pid = nil
      end

      attr_reader :name

      def start!
        return self if @start_command.empty?

        @pid = Process.spawn(@start_command, pgroup: true, out: File::NULL, err: File::NULL)
        sleep(@boot_wait_seconds) if @boot_wait_seconds.positive?
        self
      end

      def stop!
        if !@stop_command.empty?
          system(@stop_command)
          @pid = nil
          return
        end

        return unless @pid

        begin
          Process.kill("TERM", -Process.getpgid(@pid))
        rescue StandardError
          nil
        end

        begin
          Process.wait(@pid)
        rescue StandardError
          nil
        end
        @pid = nil
      end

      def metadata
        payload = { "move_endpoint" => @endpoint }
        payload["move_secret"] = @move_secret unless @move_secret.empty?
        payload
      end

      def deterministic?
        false
      end
    end
  end
end
