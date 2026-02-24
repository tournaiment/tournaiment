# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
if Rails.env.production?
  admin_email = ENV.fetch("ADMIN_EMAIL")
  admin_password = ENV.fetch("ADMIN_PASSWORD")
else
  admin_email = ENV.fetch("ADMIN_EMAIL", "admin@tournaiment.local")
  admin_password = ENV.fetch("ADMIN_PASSWORD", "password123")
end

admin = AdminUser.find_or_initialize_by(email: admin_email)
if admin.new_record?
  admin.password = admin_password
  admin.save!
  AuditLog.log!(actor: admin, action: "admin.seeded")
end

demo_agents = [
  {
    name: "Baseline",
    description: "Example agent",
    metadata: { move_endpoint: "http://localhost:4000/move" }
  },
  {
    name: "Heuristic",
    description: "Example agent",
    metadata: { move_endpoint: "http://localhost:4001/move" }
  }
]

demo_agents.each do |attrs|
  agent = Agent.find_or_initialize_by(name: attrs[:name])
  next unless agent.new_record?

  agent.description = attrs[:description]
  agent.metadata = attrs[:metadata]
  raw_key = Agent.generate_api_key
  agent.api_key = raw_key
  agent.api_key_hash = Agent.api_key_hash(raw_key)
  agent.api_key_last_rotated_at = Time.current
  agent.save!
  AuditLog.log!(actor: nil, action: "agent.seeded", auditable: agent)
end

if ENV["SEED_DEMO"] == "1"
  require_relative "../script/seed_demo_data"
end

time_control_presets = [
  {
    key: "chess_bullet_1p0",
    game_key: "chess",
    category: "bullet",
    clock_type: "increment",
    clock_config: { base_seconds: 60, increment_seconds: 0 },
    rated_allowed: true
  },
  {
    key: "chess_blitz_3p2",
    game_key: "chess",
    category: "blitz",
    clock_type: "increment",
    clock_config: { base_seconds: 180, increment_seconds: 2 },
    rated_allowed: true
  },
  {
    key: "chess_rapid_10p0",
    game_key: "chess",
    category: "rapid",
    clock_type: "increment",
    clock_config: { base_seconds: 600, increment_seconds: 0 },
    rated_allowed: true
  },
  {
    key: "go_rapid_10m_5x30",
    game_key: "go",
    category: "rapid",
    clock_type: "byoyomi",
    clock_config: { main_time_seconds: 600, period_time_seconds: 30, periods: 5 },
    rated_allowed: true
  },
  {
    key: "go_blitz_5p3",
    game_key: "go",
    category: "blitz",
    clock_type: "increment",
    clock_config: { base_seconds: 300, increment_seconds: 3 },
    rated_allowed: false
  }
]

time_control_presets.each do |attrs|
  preset = TimeControlPreset.find_or_initialize_by(key: attrs[:key])
  preset.assign_attributes(attrs)
  preset.save!
end
