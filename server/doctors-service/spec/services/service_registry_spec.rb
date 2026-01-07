# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServiceRegistry do
  let(:redis_mock) { instance_double(Redis) }

  before do
    # Reset the memoized redis instance to avoid stale doubles between tests
    ServiceRegistry.instance_variable_set(:@redis, nil)

    allow(Redis).to receive(:new).and_return(redis_mock)
    allow(redis_mock).to receive(:ping).and_return("PONG")
    allow(redis_mock).to receive(:get).and_return(nil)
    allow(redis_mock).to receive(:set)
    allow(redis_mock).to receive(:del)
    allow(redis_mock).to receive(:incr)
    allow(redis_mock).to receive(:expire)
    allow(redis_mock).to receive(:multi).and_yield(redis_mock)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
  end

  after do
    # Clean up memoized redis instance after each test
    ServiceRegistry.instance_variable_set(:@redis, nil)
  end

  describe "constants" do
    it "defines circuit breaker states" do
      expect(ServiceRegistry::CIRCUIT_CLOSED).to eq(:closed)
      expect(ServiceRegistry::CIRCUIT_OPEN).to eq(:open)
      expect(ServiceRegistry::CIRCUIT_HALF_OPEN).to eq(:half_open)
    end

    it "defines circuit breaker configuration" do
      expect(ServiceRegistry::FAILURE_THRESHOLD).to be_a(Integer)
      expect(ServiceRegistry::SUCCESS_THRESHOLD).to be_a(Integer)
      expect(ServiceRegistry::OPEN_TIMEOUT).to be_a(ActiveSupport::Duration)
      expect(ServiceRegistry::FAILURE_WINDOW).to be_a(ActiveSupport::Duration)
    end

    it "defines all services" do
      expect(ServiceRegistry::SERVICES).to have_key(:users)
      expect(ServiceRegistry::SERVICES).to have_key(:doctors)
      expect(ServiceRegistry::SERVICES).to have_key(:appointments)
      expect(ServiceRegistry::SERVICES).to have_key(:notifications)
      expect(ServiceRegistry::SERVICES).to have_key(:payments)
    end

    it "is frozen" do
      expect(ServiceRegistry::SERVICES).to be_frozen
    end

    it "each service has required configuration keys" do
      ServiceRegistry::SERVICES.each do |name, config|
        expect(config).to have_key(:env_key), "Service #{name} missing :env_key"
        expect(config).to have_key(:default_url), "Service #{name} missing :default_url"
        expect(config).to have_key(:health_path), "Service #{name} missing :health_path"
        expect(config).to have_key(:internal_path_prefix), "Service #{name} missing :internal_path_prefix"
      end
    end
  end

  describe ".url_for" do
    it "returns URL for known service" do
      url = ServiceRegistry.url_for(:doctors)
      expect(url).to include("doctors-service")
    end

    it "uses environment variable if set" do
      allow(ENV).to receive(:fetch).with("DOCTORS_SERVICE_URL", anything).and_return("http://custom-doctors:4000")

      url = ServiceRegistry.url_for(:doctors)
      expect(url).to eq("http://custom-doctors:4000")
    end

    it "raises error for unknown service" do
      expect { ServiceRegistry.url_for(:unknown) }.to raise_error(ServiceRegistry::ServiceNotFound)
    end

    it "accepts string or symbol service name" do
      expect(ServiceRegistry.url_for(:users)).to eq(ServiceRegistry.url_for("users"))
    end

    it "returns default URL when env var is not set" do
      allow(ENV).to receive(:fetch).with("USERS_SERVICE_URL", "http://users-service:3001").and_return("http://users-service:3001")

      url = ServiceRegistry.url_for(:users)
      expect(url).to eq("http://users-service:3001")
    end
  end

  describe ".health_endpoint" do
    it "returns health endpoint URL" do
      endpoint = ServiceRegistry.health_endpoint(:doctors)
      expect(endpoint).to include("/health")
    end

    it "combines base URL with health path" do
      allow(ENV).to receive(:fetch).with("DOCTORS_SERVICE_URL", anything).and_return("http://localhost:3002")

      endpoint = ServiceRegistry.health_endpoint(:doctors)
      expect(endpoint).to eq("http://localhost:3002/health")
    end
  end

  describe ".health_path_for" do
    it "returns health path" do
      path = ServiceRegistry.health_path_for(:doctors)
      expect(path).to eq("/health")
    end

    it "raises error for unknown service" do
      expect { ServiceRegistry.health_path_for(:unknown) }.to raise_error(ServiceRegistry::ServiceNotFound)
    end
  end

  describe ".internal_path_prefix" do
    it "returns internal path prefix" do
      prefix = ServiceRegistry.internal_path_prefix(:doctors)
      expect(prefix).to eq("/internal")
    end

    it "raises error for unknown service" do
      expect { ServiceRegistry.internal_path_prefix(:unknown) }.to raise_error(ServiceRegistry::ServiceNotFound)
    end
  end

  describe ".all_services" do
    it "returns all services with URLs and health paths" do
      services = ServiceRegistry.all_services

      expect(services).to have_key(:users)
      expect(services[:users]).to have_key(:url)
      expect(services[:users]).to have_key(:health_path)
    end

    it "returns transformed values for all registered services" do
      services = ServiceRegistry.all_services

      expect(services.keys).to match_array(ServiceRegistry::SERVICES.keys)
      services.each do |_name, config|
        expect(config.keys).to contain_exactly(:url, :health_path)
      end
    end
  end

  describe ".service_names" do
    it "returns array of service names" do
      names = ServiceRegistry.service_names
      expect(names).to include(:users, :doctors, :appointments, :notifications, :payments)
    end

    it "returns symbols" do
      names = ServiceRegistry.service_names
      expect(names).to all(be_a(Symbol))
    end
  end

  describe ".registered?" do
    it "returns true for registered service" do
      expect(ServiceRegistry.registered?(:doctors)).to be true
    end

    it "returns false for unregistered service" do
      expect(ServiceRegistry.registered?(:unknown)).to be false
    end

    it "accepts string service name" do
      expect(ServiceRegistry.registered?("doctors")).to be true
    end

    it "handles empty string" do
      expect(ServiceRegistry.registered?("")).to be false
    end
  end

  describe "circuit breaker" do
    describe ".healthy?" do
      it "returns true when circuit is closed" do
        allow(redis_mock).to receive(:get).and_return(nil) # nil = closed

        expect(ServiceRegistry.healthy?(:doctors)).to be true
      end

      it "returns true when circuit is half-open" do
        allow(redis_mock).to receive(:get).and_return("half_open")

        expect(ServiceRegistry.healthy?(:doctors)).to be true
      end

      it "returns false when circuit is open" do
        allow(redis_mock).to receive(:get).and_return("open")

        expect(ServiceRegistry.healthy?(:doctors)).to be false
      end
    end

    describe ".allow_request?" do
      context "when circuit is closed" do
        before do
          allow(redis_mock).to receive(:get).and_return(nil)
        end

        it "allows requests" do
          expect(ServiceRegistry.allow_request?(:doctors)).to be true
        end
      end

      context "when circuit is half-open" do
        before do
          allow(redis_mock).to receive(:get).and_return("half_open")
        end

        it "allows requests" do
          expect(ServiceRegistry.allow_request?(:doctors)).to be true
        end
      end

      context "when circuit is open" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")
        end

        context "and timeout has not elapsed" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:opened_at").and_return(Time.current.to_i.to_s)
          end

          it "does not allow requests" do
            expect(ServiceRegistry.allow_request?(:doctors)).to be false
          end
        end

        context "and timeout has elapsed" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:opened_at").and_return((Time.current - 60.seconds).to_i.to_s)
          end

          it "allows requests and transitions to half-open" do
            expect(ServiceRegistry.allow_request?(:doctors)).to be true
            expect(Rails.logger).to have_received(:info).with(/HALF-OPEN/)
          end
        end

        context "and opened_at key is missing (nil)" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:opened_at").and_return(nil)
          end

          it "allows requests (treats as timeout elapsed)" do
            expect(ServiceRegistry.allow_request?(:doctors)).to be true
          end
        end
      end

      context "when circuit state is unknown/unexpected" do
        before do
          allow(redis_mock).to receive(:get).and_return("unexpected_state")
        end

        it "allows requests (default behavior)" do
          expect(ServiceRegistry.allow_request?(:doctors)).to be true
        end
      end
    end

    describe ".record_success" do
      context "when circuit is half-open" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("half_open")
          allow(redis_mock).to receive(:get).with("circuit:doctors:successes").and_return("1")
        end

        it "increments success count" do
          expect(redis_mock).to receive(:incr).with("circuit:doctors:successes")

          ServiceRegistry.record_success(:doctors)
        end

        context "when success threshold is reached" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:successes").and_return(ServiceRegistry::SUCCESS_THRESHOLD.to_s)
          end

          it "transitions to closed and logs" do
            ServiceRegistry.record_success(:doctors)

            expect(Rails.logger).to have_received(:info).with(/Circuit CLOSED/)
          end
        end

        context "when success count is below threshold" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:successes").and_return("0")
          end

          it "does not transition to closed" do
            ServiceRegistry.record_success(:doctors)

            expect(Rails.logger).not_to have_received(:info).with(/Circuit CLOSED/)
          end
        end
      end

      context "when circuit is closed" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return(nil)
        end

        it "resets failure count" do
          expect(redis_mock).to receive(:del).with("circuit:doctors:failures")

          ServiceRegistry.record_success(:doctors)
        end
      end

      context "when circuit is open" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")
        end

        it "does not increment success count" do
          expect(redis_mock).not_to receive(:incr).with("circuit:doctors:successes")

          ServiceRegistry.record_success(:doctors)
        end
      end

      context "when redis is unavailable" do
        before do
          allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError)
        end

        it "returns without error" do
          expect { ServiceRegistry.record_success(:doctors) }.not_to raise_error
        end
      end
    end

    describe ".record_failure" do
      context "when circuit is closed" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return(nil)
          allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return("1")
        end

        it "increments failure count" do
          expect(redis_mock).to receive(:incr).with("circuit:doctors:failures")
          expect(redis_mock).to receive(:expire).with("circuit:doctors:failures", anything)

          ServiceRegistry.record_failure(:doctors)
        end

        context "when failure threshold is reached" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return(ServiceRegistry::FAILURE_THRESHOLD.to_s)
          end

          it "transitions to open and logs" do
            ServiceRegistry.record_failure(:doctors)

            expect(Rails.logger).to have_received(:warn).with(/Circuit OPENED/)
          end
        end

        context "when failure count is below threshold" do
          before do
            allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return("1")
          end

          it "does not transition to open" do
            ServiceRegistry.record_failure(:doctors)

            expect(Rails.logger).not_to have_received(:warn).with(/Circuit OPENED/)
          end
        end
      end

      context "when circuit is half-open" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        end

        it "transitions back to open" do
          ServiceRegistry.record_failure(:doctors)

          expect(Rails.logger).to have_received(:warn).with(/Circuit re-OPENED/)
        end
      end

      context "when circuit is already open" do
        before do
          allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")
        end

        it "does not increment failure count or transition" do
          expect(redis_mock).not_to receive(:incr).with("circuit:doctors:failures")
          expect(Rails.logger).not_to receive(:warn).with(/Circuit OPENED/)

          ServiceRegistry.record_failure(:doctors)
        end
      end

      context "when redis is unavailable" do
        before do
          allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError)
        end

        it "returns without error" do
          expect { ServiceRegistry.record_failure(:doctors) }.not_to raise_error
        end
      end
    end

    describe ".circuit_state" do
      it "returns closed when no state is set" do
        allow(redis_mock).to receive(:get).and_return(nil)

        expect(ServiceRegistry.circuit_state(:doctors)).to eq(:closed)
      end

      it "returns the current state" do
        allow(redis_mock).to receive(:get).and_return("open")

        expect(ServiceRegistry.circuit_state(:doctors)).to eq(:open)
      end

      it "returns half_open state" do
        allow(redis_mock).to receive(:get).and_return("half_open")

        expect(ServiceRegistry.circuit_state(:doctors)).to eq(:half_open)
      end

      context "when redis is unavailable" do
        before do
          allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError)
        end

        it "returns closed as default" do
          expect(ServiceRegistry.circuit_state(:doctors)).to eq(:closed)
        end
      end
    end

    describe ".circuit_status" do
      it "returns status for all services" do
        allow(redis_mock).to receive(:get).and_return(nil)

        status = ServiceRegistry.circuit_status

        expect(status).to have_key(:doctors)
        expect(status[:doctors]).to include(
          :state,
          :failures,
          :successes,
          :healthy,
          :url
        )
      end

      it "returns status for each registered service" do
        allow(redis_mock).to receive(:get).and_return(nil)

        status = ServiceRegistry.circuit_status

        ServiceRegistry::SERVICES.keys.each do |service_name|
          expect(status).to have_key(service_name)
        end
      end

      it "includes correct state information when open" do
        # Set default first, then override with specific keys
        allow(redis_mock).to receive(:get).and_return(nil)
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")
        allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return("3")
        allow(redis_mock).to receive(:get).with("circuit:doctors:successes").and_return("1")

        status = ServiceRegistry.circuit_status

        expect(status[:doctors][:state]).to eq(:open)
        expect(status[:doctors][:failures]).to eq(3)
        expect(status[:doctors][:successes]).to eq(1)
        expect(status[:doctors][:healthy]).to be false
      end
    end

    describe ".reset_circuit" do
      it "deletes all circuit keys for service" do
        expect(redis_mock).to receive(:multi).and_yield(redis_mock)
        expect(redis_mock).to receive(:del).with("circuit:doctors:state")
        expect(redis_mock).to receive(:del).with("circuit:doctors:failures")
        expect(redis_mock).to receive(:del).with("circuit:doctors:successes")
        expect(redis_mock).to receive(:del).with("circuit:doctors:opened_at")

        ServiceRegistry.reset_circuit(:doctors)
      end

      it "logs the reset" do
        ServiceRegistry.reset_circuit(:doctors)

        expect(Rails.logger).to have_received(:info).with(/Circuit reset/)
      end

      it "logs with service name" do
        ServiceRegistry.reset_circuit(:users)

        expect(Rails.logger).to have_received(:info).with(/Circuit reset for users/)
      end

      context "when redis is unavailable" do
        before do
          allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError)
        end

        it "returns without error" do
          expect { ServiceRegistry.reset_circuit(:doctors) }.not_to raise_error
        end
      end
    end

    describe ".reset_all_circuits" do
      it "resets circuits for all services" do
        expect(ServiceRegistry).to receive(:reset_circuit).exactly(5).times

        ServiceRegistry.reset_all_circuits
      end

      it "resets each registered service" do
        ServiceRegistry::SERVICES.keys.each do |service_name|
          expect(ServiceRegistry).to receive(:reset_circuit).with(service_name)
        end

        ServiceRegistry.reset_all_circuits
      end
    end

    describe ".redis_available?" do
      it "returns true when redis responds with PONG" do
        expect(ServiceRegistry.redis_available?).to be true
      end

      it "returns false when redis is unreachable" do
        allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError)

        expect(ServiceRegistry.redis_available?).to be false
      end

      it "logs warning when redis is unavailable" do
        allow(redis_mock).to receive(:ping).and_raise(Redis::CannotConnectError.new("Connection refused"))

        ServiceRegistry.redis_available?

        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable/)
      end

      it "returns false when redis raises other errors" do
        allow(redis_mock).to receive(:ping).and_raise(StandardError.new("Redis error"))

        expect(ServiceRegistry.redis_available?).to be false
        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable.*Redis error/)
      end

      it "returns false when redis returns unexpected value" do
        allow(redis_mock).to receive(:ping).and_return("NOT PONG")

        expect(ServiceRegistry.redis_available?).to be false
      end
    end
  end

  describe "circuit breaker transitions" do
    describe "closed -> open transition" do
      it "opens circuit after reaching failure threshold" do
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return(nil)
        allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return(ServiceRegistry::FAILURE_THRESHOLD.to_s)

        ServiceRegistry.record_failure(:doctors)

        expect(redis_mock).to have_received(:set).with("circuit:doctors:state", "open")
      end

      it "stores opened_at timestamp" do
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return(nil)
        allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return(ServiceRegistry::FAILURE_THRESHOLD.to_s)

        ServiceRegistry.record_failure(:doctors)

        expect(redis_mock).to have_received(:set).with("circuit:doctors:opened_at", anything)
      end
    end

    describe "open -> half-open transition" do
      it "transitions to half-open after timeout" do
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")
        allow(redis_mock).to receive(:get).with("circuit:doctors:opened_at").and_return((Time.current - 60.seconds).to_i.to_s)

        ServiceRegistry.allow_request?(:doctors)

        expect(redis_mock).to have_received(:set).with("circuit:doctors:state", "half_open")
      end

      it "resets success count on transition to half-open" do
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")
        allow(redis_mock).to receive(:get).with("circuit:doctors:opened_at").and_return((Time.current - 60.seconds).to_i.to_s)

        ServiceRegistry.allow_request?(:doctors)

        expect(redis_mock).to have_received(:del).with("circuit:doctors:successes")
      end
    end

    describe "half-open -> closed transition" do
      it "transitions to closed after success threshold" do
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("half_open")
        allow(redis_mock).to receive(:get).with("circuit:doctors:successes").and_return(ServiceRegistry::SUCCESS_THRESHOLD.to_s)

        ServiceRegistry.record_success(:doctors)

        # Should delete all circuit keys (transition_to_closed)
        expect(redis_mock).to have_received(:del).with("circuit:doctors:state")
        expect(redis_mock).to have_received(:del).with("circuit:doctors:failures")
        expect(redis_mock).to have_received(:del).with("circuit:doctors:successes")
        expect(redis_mock).to have_received(:del).with("circuit:doctors:opened_at")
      end
    end

    describe "half-open -> open transition" do
      it "transitions back to open on failure" do
        allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("half_open")

        ServiceRegistry.record_failure(:doctors)

        expect(redis_mock).to have_received(:set).with("circuit:doctors:state", "open")
      end
    end
  end

  describe "failure window expiration" do
    it "sets expiration on failure count" do
      allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return(nil)
      allow(redis_mock).to receive(:get).with("circuit:doctors:failures").and_return("1")

      ServiceRegistry.record_failure(:doctors)

      expect(redis_mock).to have_received(:expire).with("circuit:doctors:failures", ServiceRegistry::FAILURE_WINDOW.to_i)
    end
  end

  describe "ServiceNotFound error" do
    it "includes service name in message" do
      expect { ServiceRegistry.url_for(:nonexistent) }
        .to raise_error(ServiceRegistry::ServiceNotFound, /nonexistent/)
    end

    it "can be rescued separately from other errors" do
      expect {
        begin
          ServiceRegistry.url_for(:nonexistent)
        rescue ServiceRegistry::ServiceNotFound => e
          raise "Caught: #{e.message}"
        end
      }.to raise_error(/Caught:.*nonexistent/)
    end
  end

  describe "CircuitOpen error" do
    it "can be raised" do
      expect { raise ServiceRegistry::CircuitOpen, "Circuit is open" }
        .to raise_error(ServiceRegistry::CircuitOpen, "Circuit is open")
    end

    it "is a StandardError subclass" do
      expect(ServiceRegistry::CircuitOpen.ancestors).to include(StandardError)
    end
  end

  describe "redis key generation" do
    it "generates correct state key format" do
      allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")

      ServiceRegistry.circuit_state(:doctors)

      expect(redis_mock).to have_received(:get).with("circuit:doctors:state")
    end

    it "handles different service names correctly" do
      %i[users doctors appointments notifications payments].each do |service|
        allow(redis_mock).to receive(:get).with("circuit:#{service}:state").and_return(nil)

        ServiceRegistry.circuit_state(service)

        expect(redis_mock).to have_received(:get).with("circuit:#{service}:state")
      end
    end

    it "normalizes service name to lowercase" do
      allow(redis_mock).to receive(:get).with("circuit:doctors:state").and_return("open")

      # Using string with mixed case - should be normalized
      ServiceRegistry.circuit_state("Doctors")

      expect(redis_mock).to have_received(:get).with("circuit:doctors:state")
    end
  end
end
