# frozen_string_literal: true

class CreateAllergies < ActiveRecord::Migration[8.1]
  def change
    create_table :allergies do |t|
      t.references :user, null: false, foreign_key: true
      t.string :allergen, null: false
      t.string :severity, null: false
      t.text :reaction
      t.date :diagnosed_at
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :allergies, :severity
    add_index :allergies, :active
  end
end
