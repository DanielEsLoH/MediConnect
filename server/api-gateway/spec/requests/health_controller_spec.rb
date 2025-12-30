# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HealthController", type: :request do
  let(:mock_redis) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:new).and_return(mock_redis)
    allow(mock_redis).to receive(:ping).and_return("PONG")
    allow(mock_redis).to receive(:get).and_return(nil)
    allow(mock_redis).to receive(:flushdb).and_return("OK")
    allow(mock_redis).to receive(:del).and_return(1)
    allow(mock_redis).to receive(:multi).and_yield(mock_redis)
  end

  describe "GET /health" do
    context "when all services are healthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
      end

      it "returns ok status" do
        get "/health"

        expect(response).to have_http_status(:ok)
        expect(json_response[:status]).to eq("ok")
      end

      it "includes service name" do
        get "/health"

        expect(json_response[:service]).to eq("api-gateway")
      end

      it "includes timestamp" do
        get "/health"

        expect(json_response[:timestamp]).to be_present
      end

      it "includes database check" do
        get "/health"

        expect(json_response[:checks]).to have_key(:database)
        expect(json_response[:checks][:database][:status]).to eq("ok")
      end

      it "includes redis check" do
        get "/health"

        expect(json_response[:checks]).to have_key(:redis)
        expect(json_response[:checks][:redis][:status]).to eq("ok")
      end

      it "includes response time for checks" do
        get "/health"

        expect(json_response[:checks][:database][:response_time_ms]).to be_a(Numeric)
        expect(json_response[:checks][:redis][:response_time_ms]).to be_a(Numeric)
      end
    end

    context "when database is unhealthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "returns degraded status" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response[:status]).to eq("degraded")
      end

      it "includes database error" do
        get "/health"

        expect(json_response[:checks][:database][:status]).to eq("error")
        expect(json_response[:checks][:database][:error]).to be_present
      end
    end

    context "when redis is unhealthy" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
      end

      it "returns degraded status" do
        get "/health"

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response[:status]).to eq("degraded")
      end

      it "includes redis error" do
        get "/health"

        expect(json_response[:checks][:redis][:status]).to eq("error")
      end
    end
  end

  describe "GET /health/services" do
    before do
      # Stub all downstream service health checks
      ServiceRegistry::SERVICES.each do |service_name, config|
        base_url = config[:default_url]
        stub_request(:get, "#{base_url}/health")
          .to_return(
            status: 200,
            body: { status: "ok" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end
    end

    context "when all services are healthy" do
      it "returns ok status" do
        get "/health/services"

        expect(response).to have_http_status(:ok)
        expect(json_response[:status]).to eq("ok")
      end

      it "includes downstream services" do
        get "/health/services"

        expect(json_response[:downstream_services]).to have_key(:users)
        expect(json_response[:downstream_services]).to have_key(:doctors)
        expect(json_response[:downstream_services]).to have_key(:appointments)
      end

      it "includes circuit breaker status" do
        get "/health/services"

        expect(json_response[:circuit_breakers]).to be_present
      end

      it "includes summary" do
        get "/health/services"

        expect(json_response[:summary]).to have_key(:total_services)
        expect(json_response[:summary]).to have_key(:healthy_services)
        expect(json_response[:summary]).to have_key(:unhealthy_services)
      end

      it "shows all services healthy" do
        get "/health/services"

        expect(json_response[:summary][:healthy_services]).to eq(json_response[:summary][:total_services])
        expect(json_response[:summary][:unhealthy_services]).to eq(0)
      end
    end

    context "when some services are unhealthy" do
      before do
        # Override the users service stub to timeout
        stub_request(:get, "http://users-service:3001/health")
          .to_timeout
      end

      it "returns degraded status" do
        get "/health/services"

        expect(response).to have_http_status(:ok)
        expect(json_response[:status]).to eq("degraded")
      end

      it "shows unhealthy service count" do
        get "/health/services"

        expect(json_response[:summary][:unhealthy_services]).to be >= 1
      end
    end

    context "when all services are unhealthy" do
      before do
        ServiceRegistry::SERVICES.each do |service_name, config|
          base_url = config[:default_url]
          stub_request(:get, "#{base_url}/health")
            .to_timeout
        end
      end

      it "returns critical status" do
        get "/health/services"

        expect(response).to have_http_status(:service_unavailable)
        expect(json_response[:status]).to eq("critical")
      end
    end

    context "when circuit breaker is open" do
      before do
        # Mock the circuit breaker to be open for users service only
        # Need to mock all the ServiceRegistry calls that check_service might make
        allow(ServiceRegistry).to receive(:circuit_state).and_return(:closed)
        allow(ServiceRegistry).to receive(:circuit_state).with(:users).and_return(:open)
        allow(ServiceRegistry).to receive(:allow_request?).and_return(true)
        allow(ServiceRegistry).to receive(:allow_request?).with(:users).and_return(false)
        allow(ServiceRegistry).to receive(:circuit_status).and_return(
          users: { state: :open, failures: 5, successes: 0, healthy: false }
        )
      end

      it "shows circuit open status for that service" do
        get "/health/services"

        expect(json_response[:downstream_services][:users][:status]).to eq("circuit_open")
      end
    end
  end

  describe "GET /up" do
    it "returns ok status" do
      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end
end