# frozen_string_literal: true

class CreateDoctors < ActiveRecord::Migration[8.1]
  def change
    create_table :doctors do |t|
      t.references :specialty, null: false, foreign_key: true
      t.references :clinic, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone_number
      t.string :license_number, null: false
      t.text :bio
      t.integer :years_of_experience
      t.string :profile_picture_url
      t.jsonb :languages, default: []
      t.decimal :consultation_fee, precision: 10, scale: 2
      t.boolean :accepting_new_patients, default: true, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :doctors, :email, unique: true
    add_index :doctors, :license_number, unique: true
    add_index :doctors, :active
    add_index :doctors, :accepting_new_patients
    add_index :doctors, :languages, using: :gin
  end
end
