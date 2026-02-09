module Admin
  class StripeDashboardController < BaseController
    def show
      verify_remote = ActiveModel::Type::Boolean.new.cast(params[:verify])
      @dashboard = StripeEnvironmentDashboardService.new(verify_remote: verify_remote).call

      return unless verify_remote

      AuditLog.log!(
        actor: current_admin,
        action: "admin.stripe_dashboard_checked",
        metadata: {
          profiles: @dashboard[:profiles].map do |profile|
            {
              id: profile[:id],
              overall_status: profile.dig(:report, :overall_status),
              error_count: profile.dig(:report, :counts, :error),
              warning_count: profile.dig(:report, :counts, :warning)
            }
          end
        }
      )
    end
  end
end
