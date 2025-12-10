# frozen_string_literal: true

class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :doctor, null: false, foreign_key: true
      t.bigint :user_id, null: false
      t.integer :rating, null: false
      t.text :comment
      t.boolean :verified, default: false, null: false

      t.timestamps
    end

    add_index :reviews, :user_id
    add_index :reviews, :rating
    add_index :reviews, :verified
    add_index :reviews, [ :doctor_id, :user_id ], unique: true
  end
end
