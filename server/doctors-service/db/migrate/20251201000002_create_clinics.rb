# frozen_string_literal: true

class CreateClinics < ActiveRecord::Migration[8.1]
  def change
    create_table :clinics do |t|
      t.string :name, null: false
      t.string :address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :phone_number
      t.jsonb :operating_hours, default: {}
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :clinics, :city
    add_index :clinics, :state
    add_index :clinics, :active
    add_index :clinics, :operating_hours, using: :gin
  end
end
