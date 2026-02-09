module Admin
  class BillingHealthController < BaseController
    def show
      verify_remote = ActiveModel::Type::Boolean.new.cast(params[:verify])
      @report = StripeConfigHealthCheckService.new(verify_remote: verify_remote).call

      return unless verify_remote

      AuditLog.log!(
        actor: current_admin,
        action: "admin.billing_health_checked",
        metadata: {
          overall_status: @report[:overall_status],
          error_count: @report.dig(:counts, :error),
          warning_count: @report.dig(:counts, :warning)
        }
      )
    end
  end
end
