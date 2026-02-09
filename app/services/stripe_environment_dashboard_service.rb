class StripeEnvironmentDashboardService
  PROFILES = [
    {
      id: "local",
      label: "Local",
      env_file: ".env.local",
      rails_env: "development",
      default_dashboard_url: "https://dashboard.stripe.com/test"
    },
    {
      id: "dev",
      label: "Dev",
      env_file: ".env.dev",
      rails_env: "development",
      default_dashboard_url: "https://dashboard.stripe.com/test"
    },
    {
      id: "prod",
      label: "Prod",
      env_file: ".env.prod",
      rails_env: "production",
      default_dashboard_url: "https://dashboard.stripe.com"
    }
  ].freeze

  def initialize(root: Rails.root, verify_remote: false, env: ENV)
    @root = Pathname.new(root)
    @verify_remote = verify_remote
    @env = env
  end

  def call
    {
      checked_at: Time.current,
      verify_remote: @verify_remote,
      profiles: PROFILES.map { |profile| profile_report(profile) }
    }
  end

  private

  def profile_report(profile)
    env_file_path = @root.join(profile[:env_file])
    scoped_env = parse_env_file(env_file_path)

    report = StripeConfigHealthCheckService.new(
      verify_remote: @verify_remote,
      env: scoped_env,
      rails_env: profile[:rails_env]
    ).call

    {
      id: profile[:id],
      label: profile[:label],
      env_file: profile[:env_file],
      file_exists: env_file_path.file?,
      dashboard_url: dashboard_url_for(profile),
      report: report
    }
  end

  def dashboard_url_for(profile)
    key = "STRIPE_DASHBOARD_URL_#{profile[:id].upcase}"
    @env[key].to_s.presence || profile[:default_dashboard_url]
  end

  def parse_env_file(path)
    return {} unless path.file?

    values = {}
    path.each_line do |line|
      stripped = line.to_s.strip
      next if stripped.blank? || stripped.start_with?("#")

      parsed = stripped.sub(/\Aexport\s+/, "")
      key, raw_value = parsed.split("=", 2)
      next if key.blank?

      value = normalize_env_value(raw_value)
      values[key] = value
    end
    values
  end

  def normalize_env_value(raw)
    value = raw.to_s.strip
    return "" if value.blank?

    if value.start_with?('"') && value.end_with?('"')
      value[1..-2]
    elsif value.start_with?("'") && value.end_with?("'")
      value[1..-2]
    else
      value
    end
  end
end
