# frozen_string_literal: true

# Migration to convert all tables to UUID primary keys for distributed microservices architecture.
# This is a destructive migration - existing data will be dropped and recreated via seeds.
# IMPORTANT: Do NOT run in production without proper data migration strategy.
class MigrateToUuidPrimaryKeys < ActiveRecord::Migration[8.1]
  def up
    # Enable UUID extension for gen_random_uuid()
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Drop existing tables in reverse dependency order
    drop_table :reviews if table_exists?(:reviews)
    drop_table :schedules if table_exists?(:schedules)
    drop_table :doctors if table_exists?(:doctors)
    drop_table :clinics if table_exists?(:clinics)
    drop_table :specialties if table_exists?(:specialties)

    # Recreate specialties table with UUID primary key
    create_table :specialties, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :specialties, :name, unique: true

    # Recreate clinics table with UUID primary key
    create_table :clinics, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :name, null: false
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :phone_number
      t.jsonb :operating_hours, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :clinics, :city
    add_index :clinics, :state
    add_index :clinics, :active
    add_index :clinics, :operating_hours, using: :gin

    # Recreate doctors table with UUID primary key and UUID foreign keys
    create_table :doctors, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number
      t.uuid :specialty_id, null: false
      t.uuid :clinic_id, null: false
      t.string :license_number, null: false
      t.text :bio
      t.integer :years_of_experience
      t.decimal :consultation_fee, precision: 10, scale: 2
      t.jsonb :languages, default: []
      t.string :profile_picture_url
      t.boolean :accepting_new_patients, null: false, default: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :doctors, :email, unique: true
    add_index :doctors, :license_number, unique: true
    add_index :doctors, :specialty_id
    add_index :doctors, :clinic_id
    add_index :doctors, :accepting_new_patients
    add_index :doctors, :active
    add_index :doctors, :languages, using: :gin
    add_foreign_key :doctors, :specialties
    add_foreign_key :doctors, :clinics

    # Recreate schedules table with UUID primary key and UUID foreign key
    create_table :schedules, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.uuid :doctor_id, null: false
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :slot_duration_minutes, null: false, default: 30
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :schedules, :doctor_id
    add_index :schedules, [ :doctor_id, :day_of_week ]
    add_index :schedules, :active
    add_foreign_key :schedules, :doctors

    # Recreate reviews table with UUID primary key and UUID foreign keys
    # Note: user_id references Users Service (cross-service reference, no FK constraint)
    create_table :reviews, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.uuid :user_id, null: false
      t.uuid :doctor_id, null: false
      t.integer :rating, null: false
      t.text :comment
      t.boolean :verified, null: false, default: false

      t.timestamps
    end

    add_index :reviews, :doctor_id
    add_index :reviews, :user_id
    add_index :reviews, [ :doctor_id, :user_id ], unique: true
    add_index :reviews, :rating
    add_index :reviews, :verified
    add_foreign_key :reviews, :doctors
    # Note: No FK to users table as it's in a different service
  end

  def down
    # Drop UUID tables
    drop_table :reviews if table_exists?(:reviews)
    drop_table :schedules if table_exists?(:schedules)
    drop_table :doctors if table_exists?(:doctors)
    drop_table :clinics if table_exists?(:clinics)
    drop_table :specialties if table_exists?(:specialties)

    # Disable extension
    disable_extension 'pgcrypto' if extension_enabled?('pgcrypto')

    # Recreate tables with bigint primary keys (original schema)
    create_table :specialties do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :specialties, :name, unique: true

    create_table :clinics do |t|
      t.string :name, null: false
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :phone_number
      t.jsonb :operating_hours, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :clinics, :city
    add_index :clinics, :state
    add_index :clinics, :active
    add_index :clinics, :operating_hours, using: :gin

    create_table :doctors do |t|
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number
      t.bigint :specialty_id, null: false
      t.bigint :clinic_id, null: false
      t.string :license_number, null: false
      t.text :bio
      t.integer :years_of_experience
      t.decimal :consultation_fee, precision: 10, scale: 2
      t.jsonb :languages, default: []
      t.string :profile_picture_url
      t.boolean :accepting_new_patients, null: false, default: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :doctors, :email, unique: true
    add_index :doctors, :license_number, unique: true
    add_index :doctors, :specialty_id
    add_index :doctors, :clinic_id
    add_index :doctors, :accepting_new_patients
    add_index :doctors, :active
    add_index :doctors, :languages, using: :gin
    add_foreign_key :doctors, :specialties
    add_foreign_key :doctors, :clinics

    create_table :schedules do |t|
      t.bigint :doctor_id, null: false
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :slot_duration_minutes, null: false, default: 30
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :schedules, :doctor_id
    add_index :schedules, [ :doctor_id, :day_of_week ]
    add_index :schedules, :active
    add_foreign_key :schedules, :doctors

    create_table :reviews do |t|
      t.bigint :user_id, null: false
      t.bigint :doctor_id, null: false
      t.integer :rating, null: false
      t.text :comment
      t.boolean :verified, null: false, default: false

      t.timestamps
    end

    add_index :reviews, :doctor_id
    add_index :reviews, :user_id
    add_index :reviews, [ :doctor_id, :user_id ], unique: true
    add_index :reviews, :rating
    add_index :reviews, :verified
    add_foreign_key :reviews, :doctors
  end
end
