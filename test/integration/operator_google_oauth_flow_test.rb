require "test_helper"

class OperatorGoogleOauthFlowTest < ActionDispatch::IntegrationTest
  test "google oauth start redirects back when not configured" do
    with_env(
      "GOOGLE_OAUTH_CLIENT_ID" => nil,
      "GOOGLE_OAUTH_CLIENT_SECRET" => nil,
      "GOOGLE_OAUTH_REDIRECT_URI" => nil
    ) do
      get "/operator/oauth/google"
    end

    assert_redirected_to operator_login_path
  end

  test "google oauth callback rejects invalid state" do
    get "/operator/oauth/google/callback", params: { state: "bad", code: "abc" }
    assert_redirected_to operator_login_path
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
