module Admin
  class AgentsController < BaseController
    def index
      @agents = Agent.order(created_at: :desc)
    end

    def show
      @agent = Agent.find(params[:id])
    end

    def destroy
      agent = Agent.find(params[:id])
      agent.destroy!
      AuditLog.log!(actor: current_admin, action: "admin.agent_deleted", auditable: agent)
      redirect_to admin_agents_path, notice: "Agent deleted."
    end
  end
end
