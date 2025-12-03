class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences, id: :uuid do |t|
      t.uuid :user_id, null: false

      t.boolean :email_enabled, default: true, null: false
      t.boolean :sms_enabled, default: true, null: false
      t.boolean :push_enabled, default: true, null: false

      t.boolean :appointment_reminders, default: true, null: false
      t.boolean :appointment_updates, default: true, null: false
      t.boolean :marketing_emails, default: false, null: false

      t.timestamps
    end

    add_index :notification_preferences, :user_id, unique: true
  end
end
