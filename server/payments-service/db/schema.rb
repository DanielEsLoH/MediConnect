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

ActiveRecord::Schema[8.1].define(version: 2025_12_04_203453) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.uuid "appointment_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "description"
    t.text "failure_reason"
    t.datetime "paid_at"
    t.integer "payment_method"
    t.integer "status", default: 0, null: false
    t.string "stripe_charge_id"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["appointment_id"], name: "index_payments_on_appointment_id"
    t.index ["created_at"], name: "index_payments_on_created_at"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id", unique: true
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end
end
