require "json"
require "openssl"
require "socket"

module AssistantCompatibility
  class ScriptedMoveServer
    Request = Struct.new(:path, :headers, :body, :json, keyword_init: true)

    STATUS_TEXT = {
      200 => "OK",
      400 => "Bad Request",
      401 => "Unauthorized",
      404 => "Not Found",
      500 => "Internal Server Error"
    }.freeze

    def initialize(secret: nil, verify_signature: false)
      @secret = secret.to_s
      @verify_signature = verify_signature
      @requests = []
      @requests_mutex = Mutex.new
      @responses = Queue.new
      @server = nil
      @server_thread = nil
      @base_url = nil
      @running = false
    end

    attr_reader :base_url

    def start!
      return self if @server

      @server = TCPServer.new("127.0.0.1", 0)
      @running = true
      port = @server.addr[1]
      @server_thread = Thread.new { accept_loop }
      @base_url = "http://127.0.0.1:#{port}"
      wait_until_ready!(port)
      self
    end

    def stop!
      return unless @server

      @running = false
      begin
        @server.close
      rescue StandardError
        nil
      end
      @server_thread&.join(1)
      @server = nil
      @server_thread = nil
      @base_url = nil
    end

    def script!(responses)
      clear_responses!
      Array(responses).each do |response|
        @responses << normalize_response(response)
      end
    end

    def requests
      @requests_mutex.synchronize { @requests.dup }
    end

    private

    def accept_loop
      while @running
        client = nil
        begin
          client = @server.accept
          handle_client(client)
        rescue IOError, Errno::EBADF
          break
        rescue StandardError
          begin
            client&.close
          rescue StandardError
            nil
          end
        end
      end
    end

    def handle_client(client)
      request_line, headers, body = read_http_request(client)
      unless request_line
        write_json_response(client, 400, { error: "invalid_request" })
        return
      end

      method, path, = request_line.split(" ", 3)
      unless method == "POST" && path == "/move"
        write_json_response(client, 404, { error: "not_found" })
        return
      end

      parsed_json = parse_json(body)
      capture_request(path: path, headers: headers, body: body, json: parsed_json)

      unless signature_valid?(headers, body)
        write_json_response(client, 401, { error: "invalid_signature" })
        return
      end

      scripted = next_response
      sleep(scripted[:delay_seconds]) if scripted[:delay_seconds].positive?
      write_raw_response(client, scripted[:status], scripted[:body], scripted[:headers])
    rescue StandardError => e
      write_json_response(client, 500, { error: e.message })
    ensure
      begin
        client.close
      rescue StandardError
        nil
      end
    end

    def read_http_request(client)
      raw_headers = +""
      while !raw_headers.include?("\r\n\r\n")
        chunk = client.readpartial(1024)
        raw_headers << chunk
      end

      header_text, remaining = raw_headers.split("\r\n\r\n", 2)
      header_lines = header_text.split("\r\n")
      request_line = header_lines.shift
      headers = parse_headers(header_lines)
      content_length = headers["content-length"].to_i
      body = remaining.to_s
      if content_length > body.bytesize
        body << client.read(content_length - body.bytesize).to_s
      end

      [ request_line, headers, body ]
    rescue EOFError
      [ nil, {}, "" ]
    end

    def parse_headers(lines)
      lines.each_with_object({}) do |line, memo|
        key, value = line.split(":", 2)
        next if key.blank?

        memo[key.to_s.strip.downcase] = value.to_s.strip
      end
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def capture_request(path:, headers:, body:, json:)
      request = Request.new(path: path, headers: headers, body: body, json: json)
      @requests_mutex.synchronize { @requests << request }
    end

    def signature_valid?(headers, body)
      return true unless @verify_signature
      return false if @secret.empty?

      timestamp = headers["x-tournaiment-timestamp"].to_s
      signature = headers["x-tournaiment-signature"].to_s
      return false if timestamp.empty? || signature.empty?

      expected = OpenSSL::HMAC.hexdigest("SHA256", @secret, "#{timestamp}.#{body}")
      secure_compare(expected, signature)
    end

    def secure_compare(left, right)
      return false if left.empty? || right.empty?
      return false unless left.bytesize == right.bytesize

      ActiveSupport::SecurityUtils.secure_compare(left, right)
    end

    def next_response
      @responses.pop(true)
    rescue ThreadError
      normalize_response({ move: "resign" })
    end

    def clear_responses!
      loop { @responses.pop(true) }
    rescue ThreadError
      nil
    end

    def normalize_response(response)
      case response
      when String
        {
          status: 200,
          body: JSON.generate({ move: response }),
          delay_seconds: 0.0,
          headers: {}
        }
      when Hash
        status = response.fetch(:status, 200).to_i
        body = if response.key?(:body)
          response[:body].to_s
        else
          JSON.generate({ move: response.fetch(:move, "resign").to_s })
        end

        {
          status: status,
          body: body,
          delay_seconds: response.fetch(:delay_seconds, 0).to_f,
          headers: response.fetch(:headers, {})
        }
      else
        {
          status: 200,
          body: JSON.generate({ move: "resign" }),
          delay_seconds: 0.0,
          headers: {}
        }
      end
    end

    def write_json_response(client, status, payload)
      write_raw_response(client, status, JSON.generate(payload), { "Content-Type" => "application/json" })
    end

    def write_raw_response(client, status, body, headers)
      status_code = status.to_i
      reason = STATUS_TEXT.fetch(status_code, "OK")
      response_headers = {
        "Content-Type" => "application/json",
        "Content-Length" => body.to_s.bytesize.to_s,
        "Connection" => "close"
      }.merge(headers.transform_keys(&:to_s).transform_values(&:to_s))

      client.write("HTTP/1.1 #{status_code} #{reason}\r\n")
      response_headers.each do |key, value|
        client.write("#{key}: #{value}\r\n")
      end
      client.write("\r\n")
      client.write(body.to_s)
    end

    def wait_until_ready!(port)
      50.times do
        begin
          socket = TCPSocket.new("127.0.0.1", port)
          socket.close
          return
        rescue StandardError
          sleep 0.02
        end
      end

      raise "Scripted move server failed to start on port #{port}"
    end
  end
end
