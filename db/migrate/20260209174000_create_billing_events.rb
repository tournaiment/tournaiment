class CreateBillingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_events, id: :uuid do |t|
      t.string :external_event_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: "processed"
      t.datetime :processed_at
      t.text :error_message
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :billing_events, :external_event_id, unique: true
    add_index :billing_events, :event_type
    add_index :billing_events, :status
    add_index :billing_events, :processed_at
  end
end
