# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_03_133756) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "notification_preferences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "appointment_reminders", default: true, null: false
    t.boolean "appointment_updates", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "email_enabled", default: true, null: false
    t.boolean "marketing_emails", default: false, null: false
    t.boolean "push_enabled", default: true, null: false
    t.boolean "sms_enabled", default: true, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.datetime "delivered_at"
    t.string "delivery_method", null: false
    t.text "error_message"
    t.text "message", null: false
    t.string "notification_type", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "read_at"
    t.integer "retry_count", default: 0, null: false
    t.datetime "scheduled_for"
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["data"], name: "index_notifications_on_data", using: :gin
    t.index ["delivery_method"], name: "index_notifications_on_delivery_method"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["scheduled_for"], name: "index_notifications_on_scheduled_for"
    t.index ["status", "retry_count"], name: "index_notifications_on_status_and_retry_count"
    t.index ["status", "scheduled_for"], name: "index_notifications_on_status_and_scheduled_for"
    t.index ["status"], name: "index_notifications_on_status"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id", "status"], name: "index_notifications_on_user_id_and_status"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end
end
