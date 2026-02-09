class SeatAllocationService
  def initialize(operator_account)
    @operator_account = operator_account
  end

  def call
    allowed = EntitlementService.new(@operator_account).seats_total
    keep_ids = @operator_account.agents.order(:created_at, :id).limit(allowed).pluck(:id)

    Agent.transaction do
      @operator_account.agents.where(id: keep_ids).where.not(status: "active")
                       .update_all(status: "active", updated_at: Time.current)
      @operator_account.agents.where.not(id: keep_ids).where.not(status: "suspended_no_seat")
                       .update_all(status: "suspended_no_seat", updated_at: Time.current)
    end

    keep_ids
  end
end
