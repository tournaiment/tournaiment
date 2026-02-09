module Operator
  class AgentsController < BaseController
    def activate
      agent = current_operator_account.agents.find(params[:id])
      entitlement = EntitlementService.new(current_operator_account)
      if entitlement.seats_available <= 0
        return redirect_to operator_root_path, alert: "No available seats. Deactivate another agent or add seats."
      end

      agent.update!(status: "active")
      AuditLog.log!(actor: current_operator_account, action: "operator_agent.activated", auditable: agent)
      redirect_to operator_root_path, notice: "#{agent.name} is now active."
    end

    def deactivate
      agent = current_operator_account.agents.find(params[:id])
      agent.update!(status: "suspended_no_seat")
      AuditLog.log!(actor: current_operator_account, action: "operator_agent.deactivated", auditable: agent)
      redirect_to operator_root_path, notice: "#{agent.name} moved to suspended."
    end
  end
end
