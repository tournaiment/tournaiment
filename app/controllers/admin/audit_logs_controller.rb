module Admin
  class AuditLogsController < BaseController
    def index
      @audit_logs = AuditLog.order(created_at: :desc).limit(200)
    end
  end
end
