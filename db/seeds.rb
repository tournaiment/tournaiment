# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@tournaiment.local")
admin_password = ENV.fetch("ADMIN_PASSWORD", "password123")

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
