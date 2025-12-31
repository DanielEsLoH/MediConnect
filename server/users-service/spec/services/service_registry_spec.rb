# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServiceRegistry do
  let(:mock_redis) { instance_double(Redis) }

  before do
    # Reset the memoized redis connection
    ServiceRegistry.instance_variable_set(:@redis, nil)
    allow(Redis).to receive(:new).and_return(mock_redis)
    allow(mock_redis).to receive(:ping).and_return("PONG")
  end

  after do
    ServiceRegistry.instance_variable_set(:@redis, nil)
  end

  describe "constants" do
    it "defines CIRCUIT_CLOSED state" do
      expect(described_class::CIRCUIT_CLOSED).to eq(:closed)
    end

    it "defines CIRCUIT_OPEN state" do
      expect(described_class::CIRCUIT_OPEN).to eq(:open)
    end

    it "defines CIRCUIT_HALF_OPEN state" do
      expect(described_class::CIRCUIT_HALF_OPEN).to eq(:half_open)
    end

    it "defines FAILURE_THRESHOLD" do
      expect(described_class::FAILURE_THRESHOLD).to be_a(Integer)
      expect(described_class::FAILURE_THRESHOLD).to be > 0
    end

    it "defines SUCCESS_THRESHOLD" do
      expect(described_class::SUCCESS_THRESHOLD).to be_a(Integer)
      expect(described_class::SUCCESS_THRESHOLD).to be > 0
    end
  end

  describe ".url_for" do
    context "with registered services" do
      it "returns URL for users service" do
        expect(described_class.url_for(:users)).to include("users-service")
      end

      it "returns URL for doctors service" do
        expect(described_class.url_for(:doctors)).to include("doctors-service")
      end

      it "returns URL for appointments service" do
        expect(described_class.url_for(:appointments)).to include("appointments-service")
      end

      it "returns URL for notifications service" do
        expect(described_class.url_for(:notifications)).to include("notifications-service")
      end

      it "returns URL for payments service" do
        expect(described_class.url_for(:payments)).to include("payments-service")
      end

      it "accepts string service name" do
        expect(described_class.url_for("doctors")).to include("doctors-service")
      end

      it "uses environment variable when set" do
        allow(ENV).to receive(:fetch).with("DOCTORS_SERVICE_URL", anything).and_return("http://custom-url:8080")
        expect(described_class.url_for(:doctors)).to eq("http://custom-url:8080")
      end
    end

    context "with unknown service" do
      it "raises ServiceNotFound error" do
        expect { described_class.url_for(:unknown) }.to raise_error(
          ServiceRegistry::ServiceNotFound,
          /Service 'unknown' not found/
        )
      end

      it "includes available services in error message" do
        expect { described_class.url_for(:invalid) }.to raise_error(
          ServiceRegistry::ServiceNotFound,
          /Available:/
        )
      end
    end
  end

  describe ".health_endpoint" do
    it "returns full health check URL for a service" do
      endpoint = described_class.health_endpoint(:doctors)
      expect(endpoint).to include("doctors-service")
      expect(endpoint).to include("/health")
    end

    it "combines base URL with health path" do
      expect(described_class.health_endpoint(:users)).to match(%r{http://.*users-service.*/health})
    end
  end

  describe ".health_path_for" do
    it "returns health path for a service" do
      expect(described_class.health_path_for(:doctors)).to eq("/health")
    end

    it "raises error for unknown service" do
      expect { described_class.health_path_for(:unknown) }.to raise_error(ServiceRegistry::ServiceNotFound)
    end
  end

  describe ".internal_path_prefix" do
    it "returns internal path prefix for a service" do
      expect(described_class.internal_path_prefix(:doctors)).to eq("/internal")
    end

    it "returns internal path prefix for all services" do
      described_class.service_names.each do |service|
        expect(described_class.internal_path_prefix(service)).to eq("/internal")
      end
    end
  end

  describe ".all_services" do
    it "returns a hash of all services" do
      services = described_class.all_services
      expect(services).to be_a(Hash)
    end

    it "includes all registered services" do
      services = described_class.all_services
      expect(services.keys).to include(:users, :doctors, :appointments, :notifications, :payments)
    end

    it "includes URL and health_path for each service" do
      services = described_class.all_services
      services.each_value do |config|
        expect(config).to have_key(:url)
        expect(config).to have_key(:health_path)
      end
    end
  end

  describe ".service_names" do
    it "returns array of service names" do
      names = described_class.service_names
      expect(names).to be_an(Array)
    end

    it "includes all registered services" do
      names = described_class.service_names
      expect(names).to include(:users, :doctors, :appointments, :notifications, :payments)
    end

    it "returns symbols" do
      names = described_class.service_names
      names.each { |name| expect(name).to be_a(Symbol) }
    end
  end

  describe ".registered?" do
    it "returns true for registered services" do
      expect(described_class.registered?(:doctors)).to be true
    end

    it "returns false for unknown services" do
      expect(described_class.registered?(:unknown)).to be false
    end

    it "accepts string service name" do
      expect(described_class.registered?("doctors")).to be true
    end
  end

  describe "Circuit Breaker - Healthy Service" do
    before do
      allow(mock_redis).to receive(:get).and_return(nil)
    end

    describe ".healthy?" do
      it "returns true when circuit is CLOSED" do
        expect(described_class.healthy?(:doctors)).to be true
      end

      it "returns true when circuit is HALF_OPEN" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        expect(described_class.healthy?(:doctors)).to be true
      end

      it "returns false when circuit is OPEN" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("open")
        expect(described_class.healthy?(:doctors)).to be false
      end
    end

    describe ".allow_request?" do
      it "returns true when circuit is CLOSED" do
        expect(described_class.allow_request?(:doctors)).to be true
      end

      it "returns true when circuit is HALF_OPEN" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        expect(described_class.allow_request?(:doctors)).to be true
      end

      context "when circuit is OPEN" do
        before do
          allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("open")
        end

        it "returns false when timeout has not elapsed" do
          allow(mock_redis).to receive(:get).with("circuit:doctors:opened_at").and_return(Time.current.to_i.to_s)
          expect(described_class.allow_request?(:doctors)).to be false
        end

        it "returns true and transitions to HALF_OPEN when timeout has elapsed" do
          allow(mock_redis).to receive(:get).with("circuit:doctors:opened_at").and_return((Time.current - 60.seconds).to_i.to_s)
          allow(mock_redis).to receive(:multi).and_yield(mock_redis)
          allow(mock_redis).to receive(:set)
          allow(mock_redis).to receive(:del)

          expect(described_class.allow_request?(:doctors)).to be true
        end
      end
    end

    describe ".circuit_state" do
      it "returns CIRCUIT_CLOSED when no state in Redis" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return(nil)
        expect(described_class.circuit_state(:doctors)).to eq(:closed)
      end

      it "returns CIRCUIT_OPEN when state is open in Redis" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("open")
        expect(described_class.circuit_state(:doctors)).to eq(:open)
      end

      it "returns CIRCUIT_HALF_OPEN when state is half_open in Redis" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        expect(described_class.circuit_state(:doctors)).to eq(:half_open)
      end

      it "returns CIRCUIT_CLOSED when Redis is unavailable" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
        expect(described_class.circuit_state(:doctors)).to eq(:closed)
      end
    end
  end

  describe "Circuit Breaker - Recording Success" do
    describe ".record_success" do
      before do
        allow(mock_redis).to receive(:get)
        allow(mock_redis).to receive(:del)
        allow(mock_redis).to receive(:incr)
        allow(mock_redis).to receive(:multi).and_yield(mock_redis)
        allow(mock_redis).to receive(:set)
      end

      context "when circuit is CLOSED" do
        before do
          allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return(nil)
        end

        it "resets failure count" do
          expect(mock_redis).to receive(:del).with("circuit:doctors:failures")
          described_class.record_success(:doctors)
        end
      end

      context "when circuit is HALF_OPEN" do
        before do
          allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
          allow(mock_redis).to receive(:get).with("circuit:doctors:successes").and_return("1")
        end

        it "increments success count" do
          expect(mock_redis).to receive(:incr).with("circuit:doctors:successes")
          described_class.record_success(:doctors)
        end

        it "transitions to CLOSED after SUCCESS_THRESHOLD successes" do
          allow(mock_redis).to receive(:get).with("circuit:doctors:successes").and_return((described_class::SUCCESS_THRESHOLD).to_s)

          expect(mock_redis).to receive(:multi)
          described_class.record_success(:doctors)
        end
      end

      it "does nothing when Redis is unavailable" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
        expect { described_class.record_success(:doctors) }.not_to raise_error
      end
    end
  end

  describe "Circuit Breaker - Recording Failure" do
    describe ".record_failure" do
      before do
        allow(mock_redis).to receive(:get)
        allow(mock_redis).to receive(:incr)
        allow(mock_redis).to receive(:expire)
        allow(mock_redis).to receive(:multi).and_yield(mock_redis)
        allow(mock_redis).to receive(:set)
        allow(mock_redis).to receive(:del)
      end

      context "when circuit is CLOSED" do
        before do
          allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return(nil)
          allow(mock_redis).to receive(:get).with("circuit:doctors:failures").and_return("1")
        end

        it "increments failure count" do
          expect(mock_redis).to receive(:incr).with("circuit:doctors:failures")
          described_class.record_failure(:doctors)
        end

        it "sets expiry on failure count key" do
          expect(mock_redis).to receive(:expire).with("circuit:doctors:failures", anything)
          described_class.record_failure(:doctors)
        end

        it "transitions to OPEN after FAILURE_THRESHOLD failures" do
          allow(mock_redis).to receive(:get).with("circuit:doctors:failures").and_return((described_class::FAILURE_THRESHOLD).to_s)

          expect(mock_redis).to receive(:multi)
          described_class.record_failure(:doctors)
        end
      end

      context "when circuit is HALF_OPEN" do
        before do
          allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        end

        it "immediately transitions to OPEN" do
          expect(mock_redis).to receive(:multi)
          described_class.record_failure(:doctors)
        end
      end

      it "does nothing when Redis is unavailable" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
        expect { described_class.record_failure(:doctors) }.not_to raise_error
      end
    end
  end

  describe "Circuit Breaker - State Transitions" do
    before do
      allow(mock_redis).to receive(:get)
      allow(mock_redis).to receive(:set)
      allow(mock_redis).to receive(:del)
      allow(mock_redis).to receive(:incr)
      allow(mock_redis).to receive(:expire)
      allow(mock_redis).to receive(:multi).and_yield(mock_redis)
    end

    describe "CLOSED -> OPEN transition" do
      before do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return(nil)
      end

      it "occurs after FAILURE_THRESHOLD consecutive failures" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:failures").and_return((described_class::FAILURE_THRESHOLD).to_s)

        expect(mock_redis).to receive(:set).with("circuit:doctors:state", "open")
        described_class.record_failure(:doctors)
      end

      it "stores the time circuit was opened" do
        allow(mock_redis).to receive(:get).with("circuit:doctors:failures").and_return((described_class::FAILURE_THRESHOLD).to_s)

        expect(mock_redis).to receive(:set).with("circuit:doctors:opened_at", anything)
        described_class.record_failure(:doctors)
      end
    end

    describe "OPEN -> HALF_OPEN transition" do
      before do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("open")
        allow(mock_redis).to receive(:get).with("circuit:doctors:opened_at").and_return((Time.current - 60.seconds).to_i.to_s)
      end

      it "occurs when timeout has elapsed and request is made" do
        expect(mock_redis).to receive(:set).with("circuit:doctors:state", "half_open")
        described_class.allow_request?(:doctors)
      end
    end

    describe "HALF_OPEN -> CLOSED transition" do
      before do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        allow(mock_redis).to receive(:get).with("circuit:doctors:successes").and_return((described_class::SUCCESS_THRESHOLD).to_s)
      end

      it "occurs after SUCCESS_THRESHOLD successes" do
        expect(mock_redis).to receive(:del).with("circuit:doctors:state")
        described_class.record_success(:doctors)
      end

      it "resets all counters" do
        expect(mock_redis).to receive(:del).with("circuit:doctors:failures")
        expect(mock_redis).to receive(:del).with("circuit:doctors:successes")
        expect(mock_redis).to receive(:del).with("circuit:doctors:opened_at")
        described_class.record_success(:doctors)
      end
    end

    describe "HALF_OPEN -> OPEN transition" do
      before do
        allow(mock_redis).to receive(:get).with("circuit:doctors:state").and_return("half_open")
      end

      it "occurs on any failure in HALF_OPEN state" do
        expect(mock_redis).to receive(:set).with("circuit:doctors:state", "open")
        described_class.record_failure(:doctors)
      end
    end
  end

  describe "Redis Integration" do
    describe ".redis_available?" do
      it "returns true when Redis responds with PONG" do
        allow(mock_redis).to receive(:ping).and_return("PONG")
        expect(described_class.redis_available?).to be true
      end

      it "returns false when Redis connection fails" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
        expect(described_class.redis_available?).to be false
      end

      it "returns false when Redis times out" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::TimeoutError)
        expect(described_class.redis_available?).to be false
      end

      it "logs warning when Redis is unavailable" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError.new("Connection refused"))
        expect(Rails.logger).to receive(:warn).with(/Redis unavailable/)
        described_class.redis_available?
      end
    end

    describe "fallback behavior without Redis" do
      before do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
      end

      it "circuit_state returns CLOSED" do
        expect(described_class.circuit_state(:doctors)).to eq(:closed)
      end

      it "healthy? returns true" do
        expect(described_class.healthy?(:doctors)).to be true
      end

      it "allow_request? returns true" do
        expect(described_class.allow_request?(:doctors)).to be true
      end
    end
  end

  describe "Manual Circuit Control" do
    before do
      allow(mock_redis).to receive(:multi).and_yield(mock_redis)
      allow(mock_redis).to receive(:del)
    end

    describe ".reset_circuit" do
      it "deletes all circuit state keys for a service" do
        expect(mock_redis).to receive(:del).with("circuit:doctors:state")
        expect(mock_redis).to receive(:del).with("circuit:doctors:failures")
        expect(mock_redis).to receive(:del).with("circuit:doctors:successes")
        expect(mock_redis).to receive(:del).with("circuit:doctors:opened_at")

        described_class.reset_circuit(:doctors)
      end

      it "logs the reset" do
        expect(Rails.logger).to receive(:info).with(/Circuit reset for doctors/)
        described_class.reset_circuit(:doctors)
      end

      it "does nothing when Redis is unavailable" do
        allow(mock_redis).to receive(:ping).and_raise(Redis::CannotConnectError)
        expect { described_class.reset_circuit(:doctors) }.not_to raise_error
      end
    end

    describe ".reset_all_circuits" do
      it "resets circuits for all registered services" do
        described_class.service_names.each do |service|
          expect(mock_redis).to receive(:del).with("circuit:#{service}:state")
          expect(mock_redis).to receive(:del).with("circuit:#{service}:failures")
          expect(mock_redis).to receive(:del).with("circuit:#{service}:successes")
          expect(mock_redis).to receive(:del).with("circuit:#{service}:opened_at")
        end

        described_class.reset_all_circuits
      end
    end

    describe ".circuit_status" do
      before do
        allow(mock_redis).to receive(:get).and_return(nil)
      end

      it "returns status for all services" do
        status = described_class.circuit_status
        expect(status.keys).to match_array(described_class.service_names)
      end

      it "includes state for each service" do
        status = described_class.circuit_status
        status.each_value do |service_status|
          expect(service_status).to have_key(:state)
        end
      end

      it "includes failures count for each service" do
        status = described_class.circuit_status
        status.each_value do |service_status|
          expect(service_status).to have_key(:failures)
        end
      end

      it "includes successes count for each service" do
        status = described_class.circuit_status
        status.each_value do |service_status|
          expect(service_status).to have_key(:successes)
        end
      end

      it "includes healthy flag for each service" do
        status = described_class.circuit_status
        status.each_value do |service_status|
          expect(service_status).to have_key(:healthy)
        end
      end

      it "includes url for each service" do
        status = described_class.circuit_status
        status.each_value do |service_status|
          expect(service_status).to have_key(:url)
        end
      end
    end
  end

  describe "error classes" do
    it "defines ServiceNotFound error" do
      expect(ServiceRegistry::ServiceNotFound).to be < StandardError
    end

    it "defines CircuitOpen error" do
      expect(ServiceRegistry::CircuitOpen).to be < StandardError
    end
  end
end
