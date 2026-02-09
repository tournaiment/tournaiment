require "test_helper"

class OperatorAccountFlowTest < ActionDispatch::IntegrationTest
  test "operator signup requires email verification and sends verification OTP" do
    ActionMailer::Base.deliveries.clear

    assert_difference "OperatorAccount.count", 1 do
      post "/operator_accounts",
           params: { email: "new-operator@example.test" }
    end

    assert_response :created
    body = JSON.parse(response.body)
    refute body.key?("api_token")
    assert_equal true, body["verification_required"]
    assert_nil body["email_verified_at"]
    assert_equal "free", body.dig("entitlements", "plan")
    assert_nil body.dig("entitlements", "billing", "interval")
    assert_equal 1, body.dig("entitlements", "seats", "total")
    assert_equal false, body.dig("entitlements", "features", "ranked_enabled")
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match "Verify your Tournaiment email", ActionMailer::Base.deliveries.last.subject
  end

  test "operator me endpoint requires auth and returns entitlements" do
    operator, token = create_operator_account(plan: PlanEntitlement::PRO, addon_seats: 2)
    create_agent_for_operator(operator_account: operator, name: "OPA1")

    get "/operator_accounts/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal operator.id, body["id"]
    assert_equal "pro", body.dig("entitlements", "plan")
    assert_equal true, body.dig("entitlements", "features", "tournaments_enabled")
    assert_equal StripePriceCatalog::MONTHLY, body.dig("entitlements", "billing", "interval")
    assert_equal 3, body.dig("entitlements", "seats", "total")
    assert_equal 1, body.dig("entitlements", "seats", "used")
  end

  test "operator verifies email then logs in with OTP" do
    ActionMailer::Base.deliveries.clear
    post "/operator_accounts", params: { email: "login-operator@example.test" }
    assert_response :created

    verification_code = extract_code_from_last_email!
    post "/operator_email_verifications/confirm",
         params: {
           email: "login-operator@example.test",
           code: verification_code
         }
    assert_response :ok
    verification_body = JSON.parse(response.body)
    assert_equal "verified", verification_body["status"]

    ActionMailer::Base.deliveries.clear
    post "/operator_sessions/request_otp", params: { email: "login-operator@example.test" }
    assert_response :accepted
    login_code = extract_code_from_last_email!

    post "/operator_sessions", params: { email: "login-operator@example.test", code: login_code }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "login-operator@example.test", body["email"]
    assert body["api_token"].present?
  end

  test "operator login with OTP requires verified email" do
    operator, _token = create_operator_account(email: "unverified-operator@example.test", verified: false)

    code = OperatorOtpService.new.issue!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "123456"
    )
    assert_equal "123456", code

    post "/operator_sessions", params: { email: operator.email, code: "123456" }
    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "EMAIL_NOT_VERIFIED", body.dig("error", "code")
  end

  private

  def extract_code_from_last_email!
    email = ActionMailer::Base.deliveries.last
    assert email.present?
    content = email.body.to_s
    match = content.match(/\b(\d{6})\b/)
    assert match.present?, "Expected a 6-digit code in email body: #{content}"
    match[1]
  end
end
