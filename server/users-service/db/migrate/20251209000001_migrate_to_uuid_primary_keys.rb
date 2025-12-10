# frozen_string_literal: true

# Migration to convert all tables to UUID primary keys for distributed microservices architecture.
# This is a destructive migration - existing data will be dropped and recreated via seeds.
# IMPORTANT: Do NOT run in production without proper data migration strategy.
class MigrateToUuidPrimaryKeys < ActiveRecord::Migration[8.1]
  def up
    # Enable UUID extension for gen_random_uuid()
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Drop existing tables in reverse dependency order
    drop_table :allergies if table_exists?(:allergies)
    drop_table :medical_records if table_exists?(:medical_records)
    drop_table :users if table_exists?(:users)

    # Recreate users table with UUID primary key
    create_table :users, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number
      t.date :date_of_birth
      t.string :gender
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :profile_picture_url
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :phone_number
    add_index :users, :active

    # Recreate medical_records table with UUID primary key and UUID foreign key
    create_table :medical_records, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.uuid :user_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :record_type, null: false
      t.string :provider_name
      t.datetime :recorded_at, null: false
      t.jsonb :attachments, default: {}

      t.timestamps
    end

    add_index :medical_records, :user_id
    add_index :medical_records, :record_type
    add_index :medical_records, :recorded_at
    add_index :medical_records, :attachments, using: :gin
    add_foreign_key :medical_records, :users

    # Recreate allergies table with UUID primary key and UUID foreign key
    create_table :allergies, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.uuid :user_id, null: false
      t.string :allergen, null: false
      t.string :severity, null: false
      t.text :reaction
      t.date :diagnosed_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :allergies, :user_id
    add_index :allergies, :severity
    add_index :allergies, :active
    add_foreign_key :allergies, :users
  end

  def down
    # Drop UUID tables
    drop_table :allergies if table_exists?(:allergies)
    drop_table :medical_records if table_exists?(:medical_records)
    drop_table :users if table_exists?(:users)

    # Disable extension
    disable_extension 'pgcrypto' if extension_enabled?('pgcrypto')

    # Recreate tables with bigint primary keys (original schema)
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number
      t.date :date_of_birth
      t.string :gender
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :profile_picture_url
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :phone_number
    add_index :users, :active

    create_table :medical_records do |t|
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :record_type, null: false
      t.string :provider_name
      t.datetime :recorded_at, null: false
      t.jsonb :attachments, default: {}

      t.timestamps
    end

    add_index :medical_records, :user_id
    add_index :medical_records, :record_type
    add_index :medical_records, :recorded_at
    add_index :medical_records, :attachments, using: :gin
    add_foreign_key :medical_records, :users

    create_table :allergies do |t|
      t.bigint :user_id, null: false
      t.string :allergen, null: false
      t.string :severity, null: false
      t.text :reaction
      t.date :diagnosed_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :allergies, :user_id
    add_index :allergies, :severity
    add_index :allergies, :active
    add_foreign_key :allergies, :users
  end
end
