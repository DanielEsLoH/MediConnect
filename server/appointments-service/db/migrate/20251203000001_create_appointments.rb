# frozen_string_literal: true

class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments, id: :uuid do |t|
      # Foreign keys (UUIDs referencing other services)
      t.uuid :user_id, null: false
      t.uuid :doctor_id, null: false
      t.uuid :clinic_id, null: false

      # Appointment scheduling
      t.date :appointment_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :duration_minutes, null: false

      # Appointment type and status
      t.string :consultation_type, null: false, default: "in_person"
      t.string :status, null: false, default: "pending"

      # Financial
      t.decimal :consultation_fee, precision: 10, scale: 2

      # Medical information
      t.text :reason
      t.text :notes # Doctor's notes
      t.text :prescription

      # Confirmation tracking
      t.datetime :confirmed_at

      # Cancellation tracking
      t.datetime :cancelled_at
      t.string :cancelled_by
      t.text :cancellation_reason

      # Completion tracking
      t.datetime :completed_at

      # Request tracking
      t.string :request_id
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Indexes for performance
    add_index :appointments, :user_id
    add_index :appointments, :doctor_id
    add_index :appointments, :clinic_id
    add_index :appointments, :status
    add_index :appointments, :appointment_date
    add_index :appointments, [ :user_id, :status ]
    add_index :appointments, [ :doctor_id, :appointment_date ]
    add_index :appointments, [ :doctor_id, :status ]
    add_index :appointments, [ :appointment_date, :status ]
    add_index :appointments, :request_id, unique: true
    add_index :appointments, :consultation_type
  end
end
