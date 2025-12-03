class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.uuid :user_id, null: false

      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.jsonb :data, default: {}

      t.string :delivery_method, null: false
      t.string :status, null: false, default: 'pending'

      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at

      t.text :error_message
      t.integer :retry_count, default: 0, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_for

      t.timestamps
    end

    # Indexes for efficient queries
    add_index :notifications, :user_id
    add_index :notifications, :notification_type
    add_index :notifications, :delivery_method
    add_index :notifications, :status
    add_index :notifications, :scheduled_for
    add_index :notifications, :created_at
    add_index :notifications, [:user_id, :status]
    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:status, :scheduled_for]
    add_index :notifications, [:status, :retry_count]
    add_index :notifications, :data, using: :gin
  end
end
