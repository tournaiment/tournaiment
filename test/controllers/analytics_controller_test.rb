require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  def create_agent(name, operator_account:)
    agent, = create_agent_for_operator(operator_account: operator_account, name: name)
    agent
  end

  test "index paginates model performance table" do
    operator, = create_operator_account
    agent_a = create_agent("ANModelA", operator_account: operator)
    agent_b = create_agent("ANModelB", operator_account: operator)

    55.times do |idx|
      finished_at = Time.current - idx.minutes
      match = Match.create!(
        agent_a: agent_a,
        agent_b: agent_b,
        game_key: "chess",
        rated: false,
        status: "finished",
        result: "1-0",
        winner_side: "a",
        termination: "checkmate",
        finished_at: finished_at,
        created_at: finished_at,
        updated_at: finished_at
      )

      MatchAgentModel.create!(
        match: match,
        agent: agent_a,
        game_key: "chess",
        role: "a",
        provider: "provider-a",
        model_slug: format("model-a-%03d", idx),
        model_version: "v1"
      )
      MatchAgentModel.create!(
        match: match,
        agent: agent_b,
        game_key: "chess",
        role: "b",
        provider: "provider-b",
        model_slug: format("model-b-%03d", idx),
        model_version: "v1"
      )
    end

    get "/analytics"
    assert_response :success
    assert_match "Page 1 of 4", response.body
    assert_match "Showing 1-30 of 110 model rows", response.body

    get "/analytics", params: { page: 4 }
    assert_response :success
    assert_match "Page 4 of 4", response.body
    assert_match "Showing 91-110 of 110 model rows", response.body
  end

  test "h2h paginates match history table" do
    operator, = create_operator_account
    agent_a = create_agent("ANH2HA", operator_account: operator)
    agent_b = create_agent("ANH2HB", operator_account: operator)

    60.times do |idx|
      finished_at = Time.current - idx.hours
      Match.create!(
        agent_a: agent_a,
        agent_b: agent_b,
        game_key: "chess",
        rated: false,
        status: "finished",
        result: idx.even? ? "1-0" : "0-1",
        winner_side: idx.even? ? "a" : "b",
        termination: "checkmate",
        finished_at: finished_at,
        created_at: finished_at,
        updated_at: finished_at
      )
    end

    hidden_on_page_one = Match.where(status: "finished", game_key: "chess", agent_a: agent_a, agent_b: agent_b)
      .order(finished_at: :desc)
      .offset(30)
      .first

    get analytics_h2h_path, params: { game: "chess", agent_a: agent_a.id, agent_b: agent_b.id }
    assert_response :success
    assert_match "Page 1 of 2", response.body
    refute_match hidden_on_page_one.id, response.body

    get analytics_h2h_path, params: { game: "chess", agent_a: agent_a.id, agent_b: agent_b.id, page: 2 }
    assert_response :success
    assert_match "Page 2 of 2", response.body
    assert_match hidden_on_page_one.id, response.body
  end
end
