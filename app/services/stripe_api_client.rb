require "net/http"

class StripeApiClient
  class Error < StandardError; end

  API_BASE = "https://api.stripe.com"

  def initialize(secret_key: ENV["STRIPE_SECRET_KEY"], api_base: ENV.fetch("STRIPE_API_BASE", API_BASE))
    raise Error, "STRIPE_SECRET_KEY is not configured" if secret_key.blank?

    @secret_key = secret_key
    @api_base = api_base
  end

  def create_checkout_session(params)
    post_form("/v1/checkout/sessions", params)
  end

  def create_billing_portal_session(params)
    post_form("/v1/billing_portal/sessions", params)
  end

  def retrieve_subscription(subscription_id)
    get_json("/v1/subscriptions/#{subscription_id}")
  end

  def retrieve_price(price_id)
    get_json("/v1/prices/#{price_id}")
  end

  private

  def post_form(path, params)
    request(path: path, method: :post, body: Rack::Utils.build_nested_query(params))
  end

  def get_json(path)
    request(path: path, method: :get)
  end

  def request(path:, method:, body: nil)
    uri = URI.join(@api_base, path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    request = case method
    when :post
      Net::HTTP::Post.new(uri)
    when :get
      Net::HTTP::Get.new(uri)
    else
      raise ArgumentError, "Unsupported method: #{method}"
    end

    request.basic_auth(@secret_key, "")
    request["Content-Type"] = "application/x-www-form-urlencoded" if body.present?
    request.body = body if body.present?

    response = http.request(request)
    parsed = parse_json(response.body)

    return parsed if response.code.to_i.between?(200, 299)

    error_message = parsed.dig("error", "message").presence || "Stripe API request failed with status #{response.code}"
    raise Error, error_message
  end

  def parse_json(payload)
    return {} if payload.blank?

    JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end
end
