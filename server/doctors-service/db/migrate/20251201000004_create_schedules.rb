# frozen_string_literal: true

class CreateSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :schedules do |t|
      t.references :doctor, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :slot_duration_minutes, default: 30, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :schedules, [:doctor_id, :day_of_week]
    add_index :schedules, :active
  end
end
