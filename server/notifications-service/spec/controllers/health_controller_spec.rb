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
      expect(json["service"]).to eq("notifications-service")
    end

    it "includes timestamp" do
      get "/health"

      json = JSON.parse(response.body)
      expect(json["timestamp"]).to be_present
    end

    it "includes version" do
      get "/health"

      json = JSON.parse(response.body)
      expect(json["version"]).to be_present
    end

    it "includes checks hash" do
      get "/health"

      json = JSON.parse(response.body)
      expect(json["checks"]).to be_a(Hash)
    end

    context "when database is available" do
      it "shows database check status" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["database"]).to be_present
        expect(json["checks"]["database"]["status"]).to be_present
      end
    end

    context "when Redis is unavailable" do
      before do
        allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError.new("Connection refused"))
      end

      it "returns degraded status" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["redis"]["status"]).to eq("error")
      end
    end

    context "when RabbitMQ is unavailable" do
      before do
        bunny_double = instance_double(Bunny::Session)
        allow(Bunny).to receive(:new).and_return(bunny_double)
        allow(bunny_double).to receive(:start).and_raise(Bunny::TCPConnectionFailed.new("Connection refused"))
      end

      it "returns degraded status" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["rabbitmq"]["status"]).to eq("error")
      end
    end

    context "when all checks pass" do
      before do
        # Mock Redis
        redis_double = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_double)
        allow(redis_double).to receive(:ping).and_return("PONG")

        # Mock RabbitMQ
        bunny_double = instance_double(Bunny::Session)
        allow(Bunny).to receive(:new).and_return(bunny_double)
        allow(bunny_double).to receive(:start)
        allow(bunny_double).to receive(:close)
      end

      it "returns ok status with 200 response" do
        get "/health"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
      end
    end
  end
end
