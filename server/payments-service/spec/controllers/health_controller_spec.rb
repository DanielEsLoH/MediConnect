# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthController, type: :request do
  describe "GET /health" do
    it "returns valid JSON response" do
      get "/health"

      # Health check may return 200 or 503 depending on dependencies
      expect([ 200, 503 ]).to include(response.status)
      json = JSON.parse(response.body)
      expect(json["status"]).to be_present
    end

    it "includes service name" do
      get "/health"

      json = JSON.parse(response.body)
      expect(json["service"]).to be_present
    end

    it "includes timestamp" do
      get "/health"

      json = JSON.parse(response.body)
      expect(json["timestamp"]).to be_present
    end
  end
end
