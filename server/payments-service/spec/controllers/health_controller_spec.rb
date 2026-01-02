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

    context "when database is unavailable" do
      before do
        allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError.new("Database connection failed"))
      end

      it "returns degraded status" do
        get "/health"

        expect(response.status).to eq(503)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["database"]["status"]).to eq("error")
        expect(json["checks"]["database"]["error"]).to be_present
      end
    end

    context "when Redis is unavailable" do
      before do
        allow(Redis).to receive(:new).and_raise(StandardError.new("Redis connection failed"))
      end

      it "returns degraded status" do
        get "/health"

        expect(response.status).to eq(503)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["redis"]["status"]).to eq("error")
        expect(json["checks"]["redis"]["error"]).to be_present
      end
    end
  end
end
