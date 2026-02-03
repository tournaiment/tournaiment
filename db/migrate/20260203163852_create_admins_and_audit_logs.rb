class CreateAdminsAndAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :admins, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :admins, :email, unique: true

    create_table :audit_logs, id: :uuid do |t|
      t.string :action, null: false
      t.references :actor, type: :uuid, polymorphic: true
      t.references :auditable, type: :uuid, polymorphic: true
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
