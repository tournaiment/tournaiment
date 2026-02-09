module Operator
  class DashboardController < BaseController
    def show
      @entitlements = EntitlementService.new(current_operator_account)
      @agents = current_operator_account.agents.order(:created_at, :id)
    end

    def reallocate_seats
      keep_ids = SeatAllocationService.new(current_operator_account).call
      AuditLog.log!(
        actor: current_operator_account,
        action: "operator_account.seats_reallocated",
        metadata: { active_agent_ids: keep_ids }
      )
      redirect_to operator_root_path, notice: "Seat allocation updated."
    end
  end
end
