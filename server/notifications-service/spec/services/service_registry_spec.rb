# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServiceRegistry do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe "constants" do
    it "defines circuit states" do
      expect(described_class::CIRCUIT_CLOSED).to eq(:closed)
      expect(described_class::CIRCUIT_OPEN).to eq(:open)
      expect(described_class::CIRCUIT_HALF_OPEN).to eq(:half_open)
    end

    it "has circuit breaker configuration constants" do
      expect(described_class::FAILURE_THRESHOLD).to be_a(Integer)
      expect(described_class::SUCCESS_THRESHOLD).to be_a(Integer)
      expect(described_class::OPEN_TIMEOUT).to be_a(ActiveSupport::Duration)
      expect(described_class::FAILURE_WINDOW).to be_a(ActiveSupport::Duration)
    end

    it "has SERVICES hash with required services" do
      expect(described_class::SERVICES).to be_a(Hash)
      expect(described_class::SERVICES.keys).to include(:users, :appointments)
    end
  end

  describe ".url_for" do
    context "with known service" do
      it "returns a URL for users service" do
        result = described_class.url_for(:users)

        expect(result).to be_a(String)
        expect(result).to be_present
      end

      it "returns a URL for appointments service" do
        result = described_class.url_for(:appointments)

        expect(result).to be_a(String)
        expect(result).to be_present
      end

      it "returns a URL for doctors service" do
        result = described_class.url_for(:doctors)

        expect(result).to be_a(String)
        expect(result).to be_present
      end

      it "returns a URL for payments service" do
        result = described_class.url_for(:payments)

        expect(result).to be_a(String)
        expect(result).to be_present
      end
    end

    context "with unknown service" do
      it "raises ServiceNotFound error" do
        expect {
          described_class.url_for(:unknown_service)
        }.to raise_error(described_class::ServiceNotFound, /not found in registry/)
      end
    end
  end

  describe ".health_endpoint" do
    it "returns the full health check URL" do
      result = described_class.health_endpoint(:users)

      expect(result).to include("/health")
      expect(result).to be_a(String)
    end
  end

  describe ".health_path_for" do
    it "returns the health check path" do
      result = described_class.health_path_for(:users)

      expect(result).to eq("/health")
    end
  end

  describe ".internal_path_prefix" do
    it "returns the internal path prefix" do
      result = described_class.internal_path_prefix(:users)

      expect(result).to eq("/internal")
    end
  end

  describe ".all_services" do
    it "returns hash of all services with URLs" do
      result = described_class.all_services

      expect(result).to be_a(Hash)
      expect(result[:users]).to include(:url, :health_path)
    end
  end

  describe ".service_names" do
    it "returns array of registered service names" do
      result = described_class.service_names

      expect(result).to be_an(Array)
      expect(result).to include(:users)
      expect(result).to include(:appointments)
      expect(result).to include(:doctors)
    end
  end

  describe ".registered?" do
    it "returns true for registered service" do
      expect(described_class.registered?(:users)).to be true
    end

    it "returns false for unregistered service" do
      expect(described_class.registered?(:unknown)).to be false
    end

    it "accepts string service names" do
      expect(described_class.registered?("users")).to be true
    end
  end

  describe ".healthy?" do
    context "when circuit is closed" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:closed)
      end

      it "returns true" do
        expect(described_class.healthy?(:users)).to be true
      end
    end

    context "when circuit is open" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:open)
      end

      it "returns false" do
        expect(described_class.healthy?(:users)).to be false
      end
    end

    context "when circuit is half-open" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:half_open)
      end

      it "returns true" do
        expect(described_class.healthy?(:users)).to be true
      end
    end
  end

  describe ".allow_request?" do
    context "when circuit is closed" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:closed)
      end

      it "returns true" do
        expect(described_class.allow_request?(:users)).to be true
      end
    end

    context "when circuit is half-open" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:half_open)
      end

      it "returns true" do
        expect(described_class.allow_request?(:users)).to be true
      end
    end

    context "when circuit is open" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:open)
        allow(described_class).to receive(:circuit_open_timeout_elapsed?).and_return(false)
      end

      it "returns false when timeout has not elapsed" do
        expect(described_class.allow_request?(:users)).to be false
      end
    end

    context "when circuit is open and timeout elapsed" do
      before do
        allow(described_class).to receive(:circuit_state).and_return(:open)
        allow(described_class).to receive(:circuit_open_timeout_elapsed?).and_return(true)
        allow(described_class).to receive(:transition_to_half_open)
      end

      it "transitions to half-open and returns true" do
        expect(described_class).to receive(:transition_to_half_open).with(:users)

        expect(described_class.allow_request?(:users)).to be true
      end
    end
  end

  describe ".record_success" do
    context "when Redis is unavailable" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns early without error" do
        expect { described_class.record_success(:users) }.not_to raise_error
      end
    end

    context "when Redis is available" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(true)
      end

      context "when circuit is half-open" do
        before do
          allow(described_class).to receive(:circuit_state).and_return(:half_open)
          allow(described_class).to receive(:increment_success_count)
          allow(described_class).to receive(:success_count).and_return(1)
        end

        it "increments success count" do
          expect(described_class).to receive(:increment_success_count).with(:users)

          described_class.record_success(:users)
        end
      end

      context "when circuit is closed" do
        before do
          allow(described_class).to receive(:circuit_state).and_return(:closed)
          allow(described_class).to receive(:reset_failure_count)
        end

        it "resets failure count" do
          expect(described_class).to receive(:reset_failure_count).with(:users)

          described_class.record_success(:users)
        end
      end
    end
  end

  describe ".record_failure" do
    context "when Redis is unavailable" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns early without error" do
        expect { described_class.record_failure(:users) }.not_to raise_error
      end
    end

    context "when Redis is available" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(true)
      end

      context "when circuit is closed" do
        before do
          allow(described_class).to receive(:circuit_state).and_return(:closed)
          allow(described_class).to receive(:increment_failure_count)
          allow(described_class).to receive(:failure_count).and_return(1)
        end

        it "increments failure count" do
          expect(described_class).to receive(:increment_failure_count).with(:users)

          described_class.record_failure(:users)
        end
      end

      context "when circuit is half-open" do
        before do
          allow(described_class).to receive(:circuit_state).and_return(:half_open)
          allow(described_class).to receive(:transition_to_open)
        end

        it "transitions to open" do
          expect(described_class).to receive(:transition_to_open).with(:users)

          described_class.record_failure(:users)
        end
      end
    end
  end

  describe ".circuit_state" do
    context "when Redis is unavailable" do
      before do
        allow(described_class).to receive(:redis_available?).and_return(false)
      end

      it "returns closed" do
        expect(described_class.circuit_state(:users)).to eq(:closed)
      end
    end
  end

  describe ".circuit_status" do
    before do
      allow(described_class).to receive(:circuit_state).and_return(:closed)
      allow(described_class).to receive(:failure_count).and_return(0)
      allow(described_class).to receive(:success_count).and_return(0)
    end

    it "returns status for all services" do
      result = described_class.circuit_status

      expect(result).to be_a(Hash)
      expect(result[:users]).to include(:state, :failures, :successes, :healthy, :url)
    end
  end

  describe ".reset_circuit" do
    context "when Redis is unavailable" do
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
      allow(described_class).to receive(:reset_circuit)
    end

    it "resets circuit for all services" do
      described_class::SERVICES.keys.each do |service|
        expect(described_class).to receive(:reset_circuit).with(service)
      end

      described_class.reset_all_circuits
    end
  end

  describe ".redis_available?" do
    it "returns a boolean" do
      result = described_class.redis_available?

      expect([true, false]).to include(result)
    end
  end
end
