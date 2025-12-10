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

ActiveRecord::Schema[8.1].define(version: 2025_12_09_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "clinics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "operating_hours", default: {}
    t.string "phone_number"
    t.string "state"
    t.datetime "updated_at", null: false
    t.string "zip_code"
    t.index ["active"], name: "index_clinics_on_active"
    t.index ["city"], name: "index_clinics_on_city"
    t.index ["operating_hours"], name: "index_clinics_on_operating_hours", using: :gin
    t.index ["state"], name: "index_clinics_on_state"
  end

  create_table "doctors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "accepting_new_patients", default: true, null: false
    t.boolean "active", default: true, null: false
    t.text "bio"
    t.uuid "clinic_id", null: false
    t.decimal "consultation_fee", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.jsonb "languages", default: []
    t.string "last_name", null: false
    t.string "license_number", null: false
    t.string "phone_number"
    t.string "profile_picture_url"
    t.uuid "specialty_id", null: false
    t.datetime "updated_at", null: false
    t.integer "years_of_experience"
    t.index ["accepting_new_patients"], name: "index_doctors_on_accepting_new_patients"
    t.index ["active"], name: "index_doctors_on_active"
    t.index ["clinic_id"], name: "index_doctors_on_clinic_id"
    t.index ["email"], name: "index_doctors_on_email", unique: true
    t.index ["languages"], name: "index_doctors_on_languages", using: :gin
    t.index ["license_number"], name: "index_doctors_on_license_number", unique: true
    t.index ["specialty_id"], name: "index_doctors_on_specialty_id"
  end

  create_table "reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.uuid "doctor_id", null: false
    t.integer "rating", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.boolean "verified", default: false, null: false
    t.index ["doctor_id", "user_id"], name: "index_reviews_on_doctor_id_and_user_id", unique: true
    t.index ["doctor_id"], name: "index_reviews_on_doctor_id"
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.index ["verified"], name: "index_reviews_on_verified"
  end

  create_table "schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.uuid "doctor_id", null: false
    t.time "end_time", null: false
    t.integer "slot_duration_minutes", default: 30, null: false
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_schedules_on_active"
    t.index ["doctor_id", "day_of_week"], name: "index_schedules_on_doctor_id_and_day_of_week"
    t.index ["doctor_id"], name: "index_schedules_on_doctor_id"
  end

  create_table "specialties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_specialties_on_name", unique: true
  end

  add_foreign_key "doctors", "clinics"
  add_foreign_key "doctors", "specialties"
  add_foreign_key "reviews", "doctors"
  add_foreign_key "schedules", "doctors"
end
