# frozen_string_literal: true

class CreateSpecialties < ActiveRecord::Migration[8.1]
  def change
    create_table :specialties do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end

    add_index :specialties, :name, unique: true
  end
end
