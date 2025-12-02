# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.date :date_of_birth
      t.string :gender
      t.string :phone_number
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :profile_picture_url
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :phone_number
    add_index :users, :active
  end
end
