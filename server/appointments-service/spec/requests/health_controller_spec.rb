# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HealthController", type: :request do
  describe "GET /health" do
    context "when all services are healthy" do
      it "returns 200 OK" do
        get "/health"

        expect(response).to have_http_status(:ok)
      end

      it "returns status ok" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
      end

      it "returns service name" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["service"]).to eq("appointments-service")
      end

      it "includes timestamp" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["timestamp"]).to be_present
        expect { Time.parse(json["timestamp"]) }.not_to raise_error
      end

      it "includes version" do
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
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
          ActiveRecord::ConnectionNotEstablished.new("Database unavailable")
        )
      end

      it "returns 503 Service Unavailable" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns status degraded" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["status"]).to eq("degraded")
      end

      it "includes error message in database check" do
        get "/health"

        json = JSON.parse(response.body)
        expect(json["checks"]["database"]["status"]).to eq("error")
        expect(json["checks"]["database"]["error"]).to be_present
      end
    end
  end
end
