# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServiceRegistry do
  let(:redis) { Redis.new }

  before do
    # Clear any cached redis instance
    described_class.instance_variable_set(:@redis, nil) if described_class.instance_variable_defined?(:@redis)
    # Clear redis data
    redis.flushdb
  end

  describe "SERVICES constant" do
    it "includes all required services" do
      expect(described_class::SERVICES.keys).to contain_exactly(
        :users, :doctors, :appointments, :notifications, :payments
      )
    end

    it "has correct configuration for each service" do
      described_class::SERVICES.each do |name, config|
        expect(config).to have_key(:env_key), "#{name} missing env_key"
        expect(config).to have_key(:default_url), "#{name} missing default_url"
        expect(config).to have_key(:health_path), "#{name} missing health_path"
        expect(config).to have_key(:internal_path_prefix), "#{name} missing internal_path_prefix"
      end
    end
  end

  describe "circuit breaker constants" do
    it "has reasonable failure threshold" do
      expect(described_class::FAILURE_THRESHOLD).to eq(5)
    end

    it "has reasonable success threshold" do
      expect(described_class::SUCCESS_THRESHOLD).to eq(2)
    end

    it "has reasonable open timeout" do
      expect(described_class::OPEN_TIMEOUT).to eq(30.seconds)
    end

    it "has reasonable failure window" do
      expect(described_class::FAILURE_WINDOW).to eq(60.seconds)
    end
  end

  describe ".url_for" do
    context "with registered services" do
      it "returns URL for users service" do
        expect(described_class.url_for(:users)).to eq("http://users-service:3001")
      end

      it "returns URL for doctors service" do
        expect(described_class.url_for(:doctors)).to eq("http://doctors-service:3002")
      end

      it "returns URL for appointments service" do
        expect(described_class.url_for(:appointments)).to eq("http://appointments-service:3003")
      end

      it "returns URL for notifications service" do
        expect(described_class.url_for(:notifications)).to eq("http://notifications-service:3004")
      end

      it "returns URL for payments service" do
        expect(described_class.url_for(:payments)).to eq("http://payments-service:3005")
      end
    end

    context "with environment variable override" do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("USERS_SERVICE_URL", anything).and_return("http://custom-users:4001")
      end

      it "uses environment variable URL" do
        expect(described_class.url_for(:users)).to eq("http://custom-users:4001")
      end
    end

    context "with string service name" do
      it "accepts string service name" do
        expect(described_class.url_for("users")).to eq("http://users-service:3001")
      end
    end

    context "with unregistered service" do
      it "raises ServiceNotFound error" do
        expect { described_class.url_for(:unknown) }
          .to raise_error(described_class::ServiceNotFound, /unknown/)
      end
    end
  end

  describe ".health_endpoint" do
    it "returns complete health endpoint URL" do
      expect(described_class.health_endpoint(:users)).to eq("http://users-service:3001/health")
    end

    it "raises error for unknown service" do
      expect { described_class.health_endpoint(:unknown) }
        .to raise_error(described_class::ServiceNotFound)
    end
  end

  describe ".health_path_for" do
    it "returns health path for users service" do
      expect(described_class.health_path_for(:users)).to eq("/health")
    end

    it "returns health path for doctors service" do
      expect(described_class.health_path_for(:doctors)).to eq("/health")
    end

    it "raises error for unknown service" do
      expect { described_class.health_path_for(:unknown) }
        .to raise_error(described_class::ServiceNotFound)
    end
  end

  describe ".internal_path_prefix" do
    it "returns internal path prefix for users service" do
      expect(described_class.internal_path_prefix(:users)).to eq("/internal")
    end

    it "raises error for unknown service" do
      expect { described_class.internal_path_prefix(:unknown) }
        .to raise_error(described_class::ServiceNotFound)
    end
  end

  describe ".all_services" do
    it "returns all registered services with URLs" do
      services = described_class.all_services

      expect(services).to have_key(:users)
      expect(services).to have_key(:doctors)
      expect(services).to have_key(:appointments)
      expect(services).to have_key(:notifications)
      expect(services).to have_key(:payments)
    end

    it "returns URL and health_path for each service" do
      services = described_class.all_services

      services.each do |name, config|
        expect(config).to have_key(:url), "#{name} missing url"
        expect(config).to have_key(:health_path), "#{name} missing health_path"
      end
    end
  end

  describe ".service_names" do
    it "returns all service names" do
      expect(described_class.service_names).to contain_exactly(
        :users, :doctors, :appointments, :notifications, :payments
      )
    end
  end

  describe ".registered?" do
    it "returns true for registered services" do
      expect(described_class.registered?(:users)).to be true
      expect(described_class.registered?(:doctors)).to be true
      expect(described_class.registered?("appointments")).to be true
    end

    it "returns false for unregistered services" do
      expect(described_class.registered?(:unknown)).to be false
      expect(described_class.registered?("not_a_service")).to be false
    end
  end

  describe ".healthy?" do
    context "when circuit is closed" do
      it "returns true" do
        expect(described_class.healthy?(:users)).to be true
      end
    end

    context "when circuit is open" do
      before do
        redis.set("circuit:users:state", "open")
      end

      it "returns false" do
        expect(described_class.healthy?(:users)).to be false
      end
    end

    context "when circuit is half-open" do
      before do
        redis.set("circuit:users:state", "half_open")
      end

      it "returns true" do
        expect(described_class.healthy?(:users)).to be true
      end
    end
  end

  describe ".allow_request?" do
    context "when circuit is closed" do
      it "allows request" do
        expect(described_class.allow_request?(:users)).to be true
      end
    end

    context "when circuit is half-open" do
      before do
        redis.set("circuit:users:state", "half_open")
      end

      it "allows test request" do
        expect(described_class.allow_request?(:users)).to be true
      end
    end

    context "when circuit is open" do
      before do
        redis.set("circuit:users:state", "open")
        redis.set("circuit:users:opened_at", Time.current.to_i.to_s)
      end

      it "blocks request when timeout not elapsed" do
        expect(described_class.allow_request?(:users)).to be false
      end
    end

    context "when circuit is open but timeout elapsed" do
      before do
        redis.set("circuit:users:state", "open")
        redis.set("circuit:users:opened_at", (Time.current - 60.seconds).to_i.to_s)
      end

      it "allows request and transitions to half-open" do
        expect(described_class.allow_request?(:users)).to be true
        expect(redis.get("circuit:users:state")).to eq("half_open")
      end
    end

    context "when circuit state is unknown" do
      before do
        redis.set("circuit:users:state", "unknown_state")
      end

      it "allows request as fallback" do
        expect(described_class.allow_request?(:users)).to be true
      end
    end
  end

  describe ".record_success" do
    context "when circuit is half-open" do
      before do
        redis.set("circuit:users:state", "half_open")
        redis.set("circuit:users:successes", "0")
      end

      it "increments success count" do
        described_class.record_success(:users)
        expect(redis.get("circuit:users:successes").to_i).to eq(1)
      end

      context "when success threshold reached" do
        before do
          redis.set("circuit:users:successes", "1")
        end

        it "transitions to closed state" do
          expect(Rails.logger).to receive(:info).with(/CLOSED/)
          described_class.record_success(:users)
          # After closing, the state key is deleted (nil = closed)
          expect(redis.get("circuit:users:state")).to be_nil
        end
      end
    end

    context "when circuit is closed" do
      before do
        redis.set("circuit:users:failures", "3")
      end

      it "resets failure count" do
        described_class.record_success(:users)
        expect(redis.get("circuit:users:failures")).to be_nil
      end
    end

    context "when redis is unavailable" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns early without error" do
        expect { described_class.record_success(:users) }.not_to raise_error
      end
    end
  end

  describe ".record_failure" do
    context "when circuit is closed" do
      before do
        redis.set("circuit:users:failures", "3")
      end

      it "increments failure count" do
        described_class.record_failure(:users)
        expect(redis.get("circuit:users:failures").to_i).to eq(4)
      end

      context "when failure threshold reached" do
        before do
          redis.set("circuit:users:failures", "4")
        end

        it "transitions to open state" do
          expect(Rails.logger).to receive(:warn).with(/OPENED/)
          described_class.record_failure(:users)
          expect(redis.get("circuit:users:state")).to eq("open")
        end
      end
    end

    context "when circuit is half-open" do
      before do
        redis.set("circuit:users:state", "half_open")
      end

      it "transitions back to open state" do
        expect(Rails.logger).to receive(:warn).with(/OPENED/)
        described_class.record_failure(:users)
        expect(redis.get("circuit:users:state")).to eq("open")
      end
    end

    context "when redis is unavailable" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns early without error" do
        expect { described_class.record_failure(:users) }.not_to raise_error
      end
    end
  end

  describe ".circuit_state" do
    context "with Redis available" do
      it "returns closed when no state set" do
        expect(described_class.circuit_state(:users)).to eq(:closed)
      end

      it "returns open when state is open" do
        redis.set("circuit:users:state", "open")
        expect(described_class.circuit_state(:users)).to eq(:open)
      end

      it "returns half_open when state is half_open" do
        redis.set("circuit:users:state", "half_open")
        expect(described_class.circuit_state(:users)).to eq(:half_open)
      end
    end

    context "without Redis available" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns closed as fallback" do
        expect(described_class.circuit_state(:users)).to eq(:closed)
      end
    end
  end

  describe ".circuit_status" do
    it "returns status for all services" do
      status = described_class.circuit_status

      expect(status).to have_key(:users)
      expect(status).to have_key(:doctors)
      expect(status).to have_key(:appointments)
      expect(status).to have_key(:notifications)
      expect(status).to have_key(:payments)
    end

    it "includes all required fields for each service" do
      status = described_class.circuit_status

      status.each do |name, service_status|
        expect(service_status).to have_key(:state), "#{name} missing state"
        expect(service_status).to have_key(:failures), "#{name} missing failures"
        expect(service_status).to have_key(:successes), "#{name} missing successes"
        expect(service_status).to have_key(:healthy), "#{name} missing healthy"
        expect(service_status).to have_key(:url), "#{name} missing url"
      end
    end

    it "correctly reports healthy status" do
      redis.set("circuit:users:state", "open")

      status = described_class.circuit_status

      expect(status[:users][:healthy]).to be false
      expect(status[:doctors][:healthy]).to be true
    end
  end

  describe ".reset_circuit" do
    before do
      redis.set("circuit:users:state", "open")
      redis.set("circuit:users:failures", "5")
      redis.set("circuit:users:successes", "0")
      redis.set("circuit:users:opened_at", Time.current.to_i.to_s)
    end

    it "deletes all circuit breaker keys" do
      described_class.reset_circuit(:users)

      expect(redis.get("circuit:users:state")).to be_nil
      expect(redis.get("circuit:users:failures")).to be_nil
      expect(redis.get("circuit:users:successes")).to be_nil
      expect(redis.get("circuit:users:opened_at")).to be_nil
    end

    it "logs the reset" do
      expect(Rails.logger).to receive(:info).with(/reset/)
      described_class.reset_circuit(:users)
    end

    context "when redis is unavailable" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns early without error" do
        expect { described_class.reset_circuit(:users) }.not_to raise_error
      end
    end
  end

  describe ".reset_all_circuits" do
    before do
      described_class::SERVICES.keys.each do |service|
        redis.set("circuit:#{service}:state", "open")
      end
    end

    it "resets circuit for all services" do
      described_class.reset_all_circuits

      described_class::SERVICES.keys.each do |service|
        expect(redis.get("circuit:#{service}:state")).to be_nil
      end
    end
  end

  describe ".redis_available?" do
    context "when redis is connected" do
      it "returns true" do
        expect(described_class.redis_available?).to be true
      end
    end
  end

  describe "exception classes" do
    it "has ServiceNotFound as StandardError subclass" do
      expect(ServiceRegistry::ServiceNotFound.ancestors).to include(StandardError)
    end

    it "has CircuitOpen as StandardError subclass" do
      expect(ServiceRegistry::CircuitOpen.ancestors).to include(StandardError)
    end
  end
end