# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :request_id, :user_id
end
