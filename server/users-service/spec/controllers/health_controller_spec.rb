# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthController, type: :request do
  let(:json) { JSON.parse(response.body) }

  describe "GET /health" do
    context "when all checks pass" do
      before do
        # Mock database connection
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)

        # Mock Redis connection
        mock_redis = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(mock_redis)
        allow(mock_redis).to receive(:ping).and_return("PONG")
      end

      it "returns 200 OK" do
        get "/health"

        expect(response).to have_http_status(:ok)
      end

      it "returns correct JSON structure" do
        get "/health"

        expect(json).to include(
          "status",
          "service",
          "timestamp",
          "version",
          "checks"
        )
      end

      it "returns status ok" do
        get "/health"

        expect(json["status"]).to eq("ok")
      end

      it "returns service name" do
        get "/health"

        expect(json["service"]).to eq("users-service")
      end

      it "returns timestamp in ISO8601 format" do
        get "/health"

        expect { Time.iso8601(json["timestamp"]) }.not_to raise_error
      end

      it "returns version" do
        get "/health"

        expect(json["version"]).to be_present
      end

      it "returns database check status as ok" do
        get "/health"

        expect(json["checks"]["database"]["status"]).to eq("ok")
      end

      it "returns database response time" do
        get "/health"

        expect(json["checks"]["database"]["response_time_ms"]).to be_a(Numeric)
      end

      it "returns redis check status as ok" do
        get "/health"

        expect(json["checks"]["redis"]["status"]).to eq("ok")
      end

      it "returns redis response time" do
        get "/health"

        expect(json["checks"]["redis"]["response_time_ms"]).to be_a(Numeric)
      end
    end

    context "when database check fails" do
      before do
        # Mock database connection failure
        allow(ActiveRecord::Base.connection).to receive(:execute)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new("Connection failed"))

        # Mock Redis as healthy
        mock_redis = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(mock_redis)
        allow(mock_redis).to receive(:ping).and_return("PONG")
      end

      it "returns 503 service unavailable" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns status degraded" do
        get "/health"

        expect(json["status"]).to eq("degraded")
      end

      it "returns database check status as error" do
        get "/health"

        expect(json["checks"]["database"]["status"]).to eq("error")
      end

      it "returns database error message" do
        get "/health"

        expect(json["checks"]["database"]["error"]).to include("Connection failed")
      end

      it "still shows redis as ok" do
        get "/health"

        expect(json["checks"]["redis"]["status"]).to eq("ok")
      end
    end

    context "when redis check fails" do
      before do
        # Mock database as healthy
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)

        # Mock Redis connection failure
        allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError.new("Redis unavailable"))
      end

      it "returns 503 service unavailable" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns status degraded" do
        get "/health"

        expect(json["status"]).to eq("degraded")
      end

      it "returns redis check status as error" do
        get "/health"

        expect(json["checks"]["redis"]["status"]).to eq("error")
      end

      it "returns redis error message" do
        get "/health"

        expect(json["checks"]["redis"]["error"]).to include("Redis unavailable")
      end

      it "still shows database as ok" do
        get "/health"

        expect(json["checks"]["database"]["status"]).to eq("ok")
      end
    end

    context "when both checks fail" do
      before do
        # Mock database connection failure
        allow(ActiveRecord::Base.connection).to receive(:execute)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new("DB down"))

        # Mock Redis connection failure
        allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError.new("Redis down"))
      end

      it "returns 503 service unavailable" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns status degraded" do
        get "/health"

        expect(json["status"]).to eq("degraded")
      end

      it "shows both checks as error" do
        get "/health"

        expect(json["checks"]["database"]["status"]).to eq("error")
        expect(json["checks"]["redis"]["status"]).to eq("error")
      end
    end

    context "response time measurement" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)

        mock_redis = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(mock_redis)
        allow(mock_redis).to receive(:ping).and_return("PONG")
      end

      it "measures database response time" do
        get "/health"

        expect(json["checks"]["database"]["response_time_ms"]).to be >= 0
      end

      it "measures redis response time" do
        get "/health"

        expect(json["checks"]["redis"]["response_time_ms"]).to be >= 0
      end

      it "rounds response times to 2 decimal places" do
        get "/health"

        db_time = json["checks"]["database"]["response_time_ms"]
        redis_time = json["checks"]["redis"]["response_time_ms"]

        # Check that values are rounded (at most 2 decimal places)
        expect(db_time).to eq(db_time.round(2))
        expect(redis_time).to eq(redis_time.round(2))
      end
    end

    context "with custom version" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)

        mock_redis = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(mock_redis)
        allow(mock_redis).to receive(:ping).and_return("PONG")

        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("APP_VERSION", "1.0.0").and_return("2.5.1")
      end

      it "returns the configured version" do
        get "/health"

        expect(json["version"]).to eq("2.5.1")
      end
    end
  end
end
