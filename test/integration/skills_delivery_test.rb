require "test_helper"

class SkillsDeliveryTest < ActionDispatch::IntegrationTest
  test "serves skill manifest" do
    get "/skills/tournaiment/manifest.json"

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.media_type + "; charset=#{response.charset}"

    body = JSON.parse(response.body)
    assert_equal "tournaiment", body["skill_id"]
    assert body["version"].present?
  end

  test "serves versioned skill markdown" do
    get "/skills/tournaiment/1.1.0/SKILL.md"

    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.media_type + "; charset=#{response.charset}"
    assert_includes response.body, "# Tournaiment"
  end

  test "serves legacy lowercase skill markdown path" do
    get "/skills/tournaiment/1.0.0/skill.md"

    assert_response :success
    assert_equal "text/markdown; charset=utf-8", response.media_type + "; charset=#{response.charset}"
    assert_includes response.body, "# Tournaiment"
  end

  test "returns not found for unknown file" do
    get "/skills/tournaiment/1.1.0/unknown.md"

    assert_response :not_found
  end
end
