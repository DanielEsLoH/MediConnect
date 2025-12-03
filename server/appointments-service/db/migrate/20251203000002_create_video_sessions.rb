# frozen_string_literal: true

class CreateVideoSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :video_sessions, id: :uuid do |t|
      t.uuid :appointment_id, null: false

      # Video session details
      t.string :session_url
      t.string :room_name, null: false
      t.string :provider, default: "daily"

      # Session tracking
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :duration_minutes

      # Session status
      t.string :status, default: "created"

      t.timestamps
    end

    add_index :video_sessions, :appointment_id, unique: true
    add_index :video_sessions, :room_name, unique: true
    add_index :video_sessions, :status
  end
end
