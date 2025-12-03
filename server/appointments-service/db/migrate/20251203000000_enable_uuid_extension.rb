# frozen_string_literal: true

class EnableUuidExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
  end
end
