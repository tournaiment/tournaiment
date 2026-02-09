require "openssl"

class BillingWebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  TIMESTAMP_TOLERANCE_SECONDS = 300

  before_action :verify_webhook_signature!

  def create
    payload = parsed_payload
    result = BillingWebhookProcessor.new(payload).call

    render json: { status: "ok", duplicate: result == :duplicate }, status: :ok
  rescue JSON::ParserError
    render_api_error(code: "INVALID_BILLING_PAYLOAD", message: "Request body must be valid JSON.", status: :bad_request)
  rescue ActiveRecord::RecordNotFound, ArgumentError => e
    render_api_error(code: "INVALID_BILLING_EVENT", message: e.message, status: :unprocessable_entity)
  end

  private

  def parsed_payload
    body = request.raw_post.to_s
    return request.request_parameters if body.blank?

    JSON.parse(body)
  end

  def verify_webhook_signature!
    secret = ENV["BILLING_WEBHOOK_SECRET"].to_s
    return if secret.blank? && (Rails.env.development? || Rails.env.test?)

    if secret.blank?
      return render_api_error(
        code: "BILLING_WEBHOOK_NOT_CONFIGURED",
        message: "Billing webhook secret is not configured.",
        status: :forbidden
      )
    end

    timestamp = request.headers["X-Billing-Timestamp"].to_s
    signature = request.headers["X-Billing-Signature"].to_s

    unless timestamp.present? && signature.present?
      return render_api_error(code: "INVALID_BILLING_SIGNATURE", message: "Missing billing webhook signature headers.", status: :unauthorized)
    end

    timestamp_int = Integer(timestamp)
    if (Time.current.to_i - timestamp_int).abs > TIMESTAMP_TOLERANCE_SECONDS
      return render_api_error(code: "INVALID_BILLING_SIGNATURE", message: "Billing webhook timestamp is outside the allowed window.", status: :unauthorized)
    end

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{request.raw_post}")
    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      return render_api_error(code: "INVALID_BILLING_SIGNATURE", message: "Billing webhook signature verification failed.", status: :unauthorized)
    end
  rescue ArgumentError
    render_api_error(code: "INVALID_BILLING_SIGNATURE", message: "Invalid billing webhook timestamp.", status: :unauthorized)
  end
end
