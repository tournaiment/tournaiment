module Admin
  class OperatorAccountsController < BaseController
    def index
      @operator_accounts = OperatorAccount.includes(:plan_entitlement, :agents).order(created_at: :desc)
    end

    def show
      @operator_account = OperatorAccount.includes(:plan_entitlement, :agents).find(params[:id])
      @entitlements = EntitlementService.new(@operator_account)
      @agents = @operator_account.agents.order(:created_at, :id)
    end

    def reallocate_seats
      operator_account = OperatorAccount.find(params[:id])
      active_ids = SeatAllocationService.new(operator_account).call
      AuditLog.log!(
        actor: current_admin,
        action: "admin.operator_account_seats_reallocated",
        auditable: operator_account,
        metadata: { active_agent_ids: active_ids }
      )
      redirect_to admin_operator_account_path(operator_account), notice: "Seat allocation recalculated."
    end
  end
end
