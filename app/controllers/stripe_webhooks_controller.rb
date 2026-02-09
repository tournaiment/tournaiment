require "openssl"

class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  TIMESTAMP_TOLERANCE_SECONDS = 300

  before_action :verify_stripe_signature!

  def create
    event = parse_event_payload
    mapped = StripeEventMapper.new(event).to_billing_event_payload

    if mapped.present?
      result = BillingWebhookProcessor.new(mapped).call
      render json: { status: "ok", duplicate: result == :duplicate }, status: :ok
    else
      render json: { status: "ignored" }, status: :ok
    end
  rescue JSON::ParserError
    render_api_error(code: "INVALID_STRIPE_PAYLOAD", message: "Stripe webhook body must be valid JSON.", status: :bad_request)
  rescue ActiveRecord::RecordNotFound, ArgumentError, StripeApiClient::Error => e
    render_api_error(code: "INVALID_STRIPE_EVENT", message: e.message, status: :unprocessable_entity)
  end

  private

  def parse_event_payload
    JSON.parse(request.raw_post.to_s)
  end

  def verify_stripe_signature!
    secret = ENV["STRIPE_WEBHOOK_SECRET"].to_s
    return if secret.blank? && (Rails.env.development? || Rails.env.test?)

    if secret.blank?
      return render_api_error(code: "STRIPE_WEBHOOK_NOT_CONFIGURED", message: "Stripe webhook secret is not configured.", status: :forbidden)
    end

    signature_header = request.headers["Stripe-Signature"].to_s
    timestamp, signatures = parse_signature_header(signature_header)
    unless timestamp.present? && signatures.any?
      return render_api_error(code: "INVALID_STRIPE_SIGNATURE", message: "Missing Stripe webhook signature values.", status: :unauthorized)
    end

    timestamp_value = Integer(timestamp)
    if (Time.current.to_i - timestamp_value).abs > TIMESTAMP_TOLERANCE_SECONDS
      return render_api_error(code: "INVALID_STRIPE_SIGNATURE", message: "Stripe webhook timestamp is outside the allowed window.", status: :unauthorized)
    end

    signed_payload = "#{timestamp_value}.#{request.raw_post}"
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)
    unless signatures.any? { |signature| secure_compare(expected, signature) }
      return render_api_error(code: "INVALID_STRIPE_SIGNATURE", message: "Stripe webhook signature verification failed.", status: :unauthorized)
    end
  rescue ArgumentError
    render_api_error(code: "INVALID_STRIPE_SIGNATURE", message: "Invalid Stripe webhook signature header.", status: :unauthorized)
  end

  def parse_signature_header(header)
    parts = header.split(",").map { |segment| segment.strip.split("=", 2) }.select { |pair| pair.length == 2 }
    timestamp = parts.find { |key, _value| key == "t" }&.last
    signatures = parts.select { |key, _value| key == "v1" }.map(&:last)
    [ timestamp, signatures ]
  end

  def secure_compare(expected, actual)
    return false if expected.blank? || actual.blank?
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end
end
