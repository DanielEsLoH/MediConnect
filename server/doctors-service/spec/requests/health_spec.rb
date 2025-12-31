# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health", type: :request do
  describe "GET /health" do
    let(:redis_mock) { instance_double(Redis) }

    before do
      allow(Redis).to receive(:new).and_return(redis_mock)
      allow(redis_mock).to receive(:ping).and_return("PONG")
    end

    context "when all services are healthy" do
      it "returns ok status" do
        get "/health"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["status"]).to eq("ok")
      end

      it "returns service name" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["service"]).to eq("doctors-service")
      end

      it "returns timestamp" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["timestamp"]).to be_present
        expect { Time.parse(json["timestamp"]) }.not_to raise_error
      end

      it "returns version" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["version"]).to be_present
      end

      it "includes database check" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["database"]["status"]).to eq("ok")
        expect(json["checks"]["database"]["response_time_ms"]).to be_a(Numeric)
      end

      it "includes redis check" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["redis"]["status"]).to eq("ok")
        expect(json["checks"]["redis"]["response_time_ms"]).to be_a(Numeric)
      end
    end

    context "when database is unhealthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad.new("Connection refused"))
      end

      it "returns degraded status" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)

        expect(json["status"]).to eq("degraded")
      end

      it "includes database error" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["database"]["status"]).to eq("error")
        expect(json["checks"]["database"]["error"]).to be_present
      end
    end

    context "when redis is unhealthy" do
      before do
        allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError.new("Connection refused"))
      end

      it "returns degraded status" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)

        expect(json["status"]).to eq("degraded")
      end

      it "includes redis error" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["redis"]["status"]).to eq("error")
        expect(json["checks"]["redis"]["error"]).to be_present
      end

      it "database check still succeeds" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["database"]["status"]).to eq("ok")
      end
    end

    context "when both services are unhealthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad.new("Connection refused"))
        allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError.new("Connection refused"))
      end

      it "returns degraded status" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)

        expect(json["status"]).to eq("degraded")
        expect(json["checks"]["database"]["status"]).to eq("error")
        expect(json["checks"]["redis"]["status"]).to eq("error")
      end
    end

    context "with custom APP_VERSION environment variable" do
      around do |example|
        original_version = ENV["APP_VERSION"]
        ENV["APP_VERSION"] = "2.5.0"
        example.run
        ENV["APP_VERSION"] = original_version
      end

      it "returns custom version" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["version"]).to eq("2.5.0")
      end
    end
  end

  describe "GET /up" do
    it "returns success for Rails built-in health check" do
      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end
end