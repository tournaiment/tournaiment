class BillingCheckoutSessionsController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_operator_for_billing!

  def create
    entitlement = EntitlementService.new(@current_operator_account)
    intent = params[:intent].to_s

    case intent
    when "upgrade_to_pro"
      return respond_checkout_error(code: "ALREADY_PRO", message: "Account is already on pro.", status: :conflict) if entitlement.pro?

      return unless ensure_monthly_billing_interval!

      return render_stripe_upgrade_session! if stripe_upgrade_enabled?

      session = checkout_payload(
        intent: intent,
        line_items: [ { sku: "pro_plan", interval: StripePriceCatalog::MONTHLY, quantity: 1 } ],
        event_preview: {
          type: "subscription.activated",
          data: {
            operator_account_id: @current_operator_account.id,
            plan: "pro",
            subscription_status: "active",
            billing_interval: StripePriceCatalog::MONTHLY,
            addon_seats: 0
          }
        }
      )
      return render_checkout_session!(session)
    when "add_seats"
      unless entitlement.seat_addons_enabled?
        return respond_checkout_error(
          code: "PRO_REQUIRED_FOR_SEAT_ADDONS",
          message: "Seat add-ons require a pro plan.",
          status: :forbidden,
          required: [ "pro_plan" ]
        )
      end

      return render_stripe_billing_portal_session! if stripe_portal_enabled?

      quantity = Integer(params[:quantity])
      if quantity <= 0
        return respond_checkout_error(code: "INVALID_SEAT_QUANTITY", message: "Seat quantity must be greater than zero.", status: :unprocessable_entity)
      end

      session = checkout_payload(
        intent: intent,
        line_items: [ { sku: "agent_seat_addon", quantity: quantity } ],
        event_preview: {
          type: "seat_addon.updated",
          data: {
            operator_account_id: @current_operator_account.id,
            addon_seats: entitlement.addon_seats + quantity
          }
        }
      )
      return render_checkout_session!(session)
    else
      respond_checkout_error(code: "INVALID_CHECKOUT_INTENT", message: "Unsupported checkout intent.", status: :unprocessable_entity)
    end
  rescue ArgumentError, TypeError
    respond_checkout_error(code: "INVALID_SEAT_QUANTITY", message: "Seat quantity must be an integer greater than zero.", status: :unprocessable_entity)
  end

  private

  def authenticate_operator_for_billing!
    if auth_token_from_headers.present? || request.format.json?
      authenticate_operator!
    else
      require_operator_session!
    end
  end

  def render_stripe_upgrade_session!
    pro_price_id = StripePriceCatalog.pro_price_id
    unless pro_price_id
      return respond_checkout_error(
        code: "STRIPE_PRICE_NOT_CONFIGURED",
        message: "Monthly pro plan price is not configured.",
        status: :unprocessable_entity
      )
    end

    stripe = StripeApiClient.new
    stripe_params = {
      mode: "subscription",
      success_url: params[:success_url].presence || "#{request.base_url}/operator?billing=success",
      cancel_url: params[:cancel_url].presence || "#{request.base_url}/operator?billing=cancelled",
      client_reference_id: @current_operator_account.id,
      line_items: [ { price: pro_price_id, quantity: 1 } ],
      metadata: {
        operator_account_id: @current_operator_account.id,
        intent: "upgrade_to_pro",
        billing_interval: StripePriceCatalog::MONTHLY
      },
      subscription_data: {
        metadata: {
          operator_account_id: @current_operator_account.id,
          billing_interval: StripePriceCatalog::MONTHLY
        }
      }
    }
    customer_id = @current_operator_account.stripe_customer_id.presence
    if customer_id.present?
      stripe_params[:customer] = customer_id
    else
      stripe_params[:customer_email] = @current_operator_account.email
    end

    session = stripe.create_checkout_session(stripe_params)

    @current_operator_account.sync_stripe_references!(customer_id: session["customer"])
    AuditLog.log!(
      actor: @current_operator_account,
      action: "billing.checkout_session_created",
      metadata: {
        provider: "stripe",
        intent: "upgrade_to_pro",
        billing_interval: StripePriceCatalog::MONTHLY,
        price_id: pro_price_id,
        checkout_session_id: session["id"]
      }
    )

    response_payload = {
      id: session["id"],
      provider: "stripe",
      intent: "upgrade_to_pro",
      billing_interval: StripePriceCatalog::MONTHLY,
      status: session["status"],
      url: session["url"]
    }
    respond_with_checkout_session!(response_payload)
  rescue StripeApiClient::Error => e
    respond_checkout_error(code: "STRIPE_CHECKOUT_FAILED", message: e.message, status: :unprocessable_entity)
  end

  def render_stripe_billing_portal_session!
    customer_id = @current_operator_account.stripe_customer_id
    if customer_id.blank?
      return respond_checkout_error(
        code: "STRIPE_CUSTOMER_REQUIRED",
        message: "Stripe customer record missing. Complete a pro upgrade checkout first.",
        status: :unprocessable_entity
      )
    end

    stripe = StripeApiClient.new
    session = stripe.create_billing_portal_session(
      customer: customer_id,
      return_url: params[:return_url].presence || "#{request.base_url}/operator"
    )

    AuditLog.log!(
      actor: @current_operator_account,
      action: "billing.portal_session_created",
      metadata: {
        provider: "stripe",
        portal_session_id: session["id"]
      }
    )

    response_payload = {
      id: session["id"],
      provider: "stripe",
      intent: "add_seats",
      status: "pending",
      url: session["url"]
    }
    respond_with_checkout_session!(response_payload)
  rescue StripeApiClient::Error => e
    respond_checkout_error(code: "STRIPE_PORTAL_FAILED", message: e.message, status: :unprocessable_entity)
  end

  def stripe_upgrade_enabled?
    !Rails.env.test? && ENV["STRIPE_SECRET_KEY"].present? && StripePriceCatalog.any_pro_price_configured?
  end

  def stripe_portal_enabled?
    !Rails.env.test? && ENV["STRIPE_SECRET_KEY"].present?
  end

  def checkout_payload(intent:, line_items:, event_preview:)
    {
      id: "chk_#{SecureRandom.hex(12)}",
      intent: intent,
      status: "pending",
      line_items: line_items,
      event_preview: event_preview
    }
  end

  def ensure_monthly_billing_interval!
    raw = params[:billing_interval].presence || params[:interval].presence
    return true if raw.blank?

    interval = StripePriceCatalog.normalize_interval_strict(raw)
    return true if interval == StripePriceCatalog::MONTHLY

    respond_checkout_error(
      code: "INVALID_BILLING_INTERVAL",
      message: "Only monthly billing is supported.",
      status: :unprocessable_entity
    )
    false
  end

  def render_checkout_session!(session)
    AuditLog.log!(
      actor: @current_operator_account,
      action: "billing.checkout_session_created",
      metadata: {
        intent: session[:intent],
        line_items: session[:line_items],
        checkout_session_id: session[:id]
      }
    )
    respond_with_checkout_session!(session)
  end

  def respond_with_checkout_session!(payload)
    if api_request?
      render json: payload, status: :created
      return
    end

    if payload[:url].present? || payload["url"].present?
      redirect_to(payload[:url] || payload["url"], allow_other_host: true)
    else
      redirect_to operator_root_path, notice: "Billing session generated."
    end
  end

  def respond_checkout_error(code:, message:, status:, required: nil)
    if api_request?
      render_api_error(code: code, message: message, status: status, required: required)
    else
      redirect_to operator_root_path, alert: message
    end
  end

  def api_request?
    auth_token_from_headers.present? || request.format.json?
  end
end
