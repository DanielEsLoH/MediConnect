# frozen_string_literal: true

class CreateMedicalRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :medical_records do |t|
      t.references :user, null: false, foreign_key: true
      t.string :record_type, null: false
      t.string :title, null: false
      t.text :description
      t.datetime :recorded_at, null: false
      t.string :provider_name
      t.jsonb :attachments, default: {}

      t.timestamps
    end

    add_index :medical_records, :record_type
    add_index :medical_records, :recorded_at
    add_index :medical_records, :attachments, using: :gin
  end
end
