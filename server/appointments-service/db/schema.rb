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

ActiveRecord::Schema[8.1].define(version: 2025_12_03_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "appointments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "appointment_date", null: false
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.string "cancelled_by"
    t.uuid "clinic_id", null: false
    t.datetime "completed_at"
    t.datetime "confirmed_at"
    t.decimal "consultation_fee", precision: 10, scale: 2
    t.string "consultation_type", default: "in_person", null: false
    t.datetime "created_at", null: false
    t.uuid "doctor_id", null: false
    t.integer "duration_minutes", null: false
    t.time "end_time", null: false
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.text "prescription"
    t.text "reason"
    t.string "request_id"
    t.time "start_time", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["appointment_date", "status"], name: "index_appointments_on_appointment_date_and_status"
    t.index ["appointment_date"], name: "index_appointments_on_appointment_date"
    t.index ["clinic_id"], name: "index_appointments_on_clinic_id"
    t.index ["consultation_type"], name: "index_appointments_on_consultation_type"
    t.index ["doctor_id", "appointment_date"], name: "index_appointments_on_doctor_id_and_appointment_date"
    t.index ["doctor_id", "status"], name: "index_appointments_on_doctor_id_and_status"
    t.index ["doctor_id"], name: "index_appointments_on_doctor_id"
    t.index ["request_id"], name: "index_appointments_on_request_id", unique: true
    t.index ["status"], name: "index_appointments_on_status"
    t.index ["user_id", "status"], name: "index_appointments_on_user_id_and_status"
    t.index ["user_id"], name: "index_appointments_on_user_id"
  end

  create_table "video_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "appointment_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.datetime "ended_at"
    t.string "provider", default: "daily"
    t.string "room_name", null: false
    t.string "session_url"
    t.datetime "started_at"
    t.string "status", default: "created"
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_video_sessions_on_appointment_id", unique: true
    t.index ["room_name"], name: "index_video_sessions_on_room_name", unique: true
    t.index ["status"], name: "index_video_sessions_on_status"
  end
end
