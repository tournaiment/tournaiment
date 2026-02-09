require "cgi"
require "net/http"

class GoogleOauthClient
  class Error < StandardError; end

  AUTH_URI = "https://accounts.google.com/o/oauth2/v2/auth"
  TOKEN_URI = URI("https://oauth2.googleapis.com/token")
  TOKENINFO_URI = URI("https://oauth2.googleapis.com/tokeninfo")

  def initialize(
    client_id: ENV["GOOGLE_OAUTH_CLIENT_ID"],
    client_secret: ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
    redirect_uri: ENV["GOOGLE_OAUTH_REDIRECT_URI"]
  )
    @client_id = client_id.to_s.strip
    @client_secret = client_secret.to_s.strip
    @redirect_uri = redirect_uri.to_s.strip
  end

  def configured?
    @client_id.present? && @client_secret.present? && @redirect_uri.present?
  end

  def authorization_url(state:)
    raise Error, "Google OAuth is not configured" unless configured?

    query = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      response_type: "code",
      scope: "openid email profile",
      access_type: "online",
      include_granted_scopes: "true",
      prompt: "select_account",
      state: state
    }
    "#{AUTH_URI}?#{Rack::Utils.build_query(query)}"
  end

  def exchange_code_for_verified_email!(code)
    raise Error, "Google OAuth is not configured" unless configured?
    raise Error, "Missing Google authorization code" if code.to_s.strip.blank?

    token = exchange_code_for_token!(code.to_s)
    id_token = token["id_token"].to_s
    raise Error, "Google token response missing id_token" if id_token.blank?

    token_info = fetch_token_info!(id_token)
    aud = token_info["aud"].to_s
    raise Error, "Google token audience mismatch" if aud != @client_id

    email_verified = ActiveModel::Type::Boolean.new.cast(token_info["email_verified"])
    raise Error, "Google account email is not verified" unless email_verified

    email = token_info["email"].to_s.strip.downcase
    raise Error, "Google token missing email" if email.blank?

    email
  end

  private

  def exchange_code_for_token!(code)
    request = Net::HTTP::Post.new(TOKEN_URI)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = Rack::Utils.build_query(
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      grant_type: "authorization_code",
      code: code
    )

    response = http_for(TOKEN_URI).request(request)
    payload = parse_json(response.body)
    return payload if response.code.to_i.between?(200, 299)

    raise Error, payload["error_description"].presence || payload["error"].presence || "Google token exchange failed"
  end

  def fetch_token_info!(id_token)
    uri = TOKENINFO_URI.dup
    uri.query = Rack::Utils.build_query(id_token: id_token)
    response = http_for(uri).request(Net::HTTP::Get.new(uri))
    payload = parse_json(response.body)
    return payload if response.code.to_i.between?(200, 299)

    raise Error, payload["error_description"].presence || payload["error"].presence || "Google token validation failed"
  end

  def http_for(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https")
  end

  def parse_json(body)
    return {} if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    {}
  end
end
