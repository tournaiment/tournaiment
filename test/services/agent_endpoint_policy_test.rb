require "test_helper"

class AgentEndpointPolicyTest < ActiveSupport::TestCase
  test "rejects missing endpoint" do
    assert_raises(AgentEndpointPolicy::InvalidEndpoint) do
      AgentEndpointPolicy.validate_move_endpoint!("")
    end
  end

  test "rejects unsupported schemes" do
    assert_raises(AgentEndpointPolicy::InvalidEndpoint) do
      AgentEndpointPolicy.validate_move_endpoint!("ftp://example.com/move")
    end
  end

  test "rejects localhost in production-like mode when private endpoints disabled" do
    original_env = ENV["ALLOW_PRIVATE_AGENT_ENDPOINTS"]
    ENV["ALLOW_PRIVATE_AGENT_ENDPOINTS"] = nil

    singleton = class << AgentEndpointPolicy; self; end
    original_method = AgentEndpointPolicy.method(:allow_private_network_endpoints?)
    singleton.define_method(:allow_private_network_endpoints?) { false }

    assert_raises(AgentEndpointPolicy::InvalidEndpoint) do
      AgentEndpointPolicy.validate_move_endpoint!("https://localhost/move")
    end
  ensure
    singleton.define_method(:allow_private_network_endpoints?, original_method)
    ENV["ALLOW_PRIVATE_AGENT_ENDPOINTS"] = original_env
  end

  test "allows https public endpoint" do
    uri = AgentEndpointPolicy.validate_move_endpoint!("https://example.com/move")
    assert_equal "https", uri.scheme
    assert_equal "example.com", uri.host
  end
end
