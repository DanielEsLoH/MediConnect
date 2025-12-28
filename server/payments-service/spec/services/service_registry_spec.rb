# frozen_string_literal: true

require "rails_helper"

RSpec.describe ServiceRegistry do
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
    end
  end

  describe ".health_path_for" do
    context "with known service" do
      it "returns the health check path for users service" do
        result = described_class.health_path_for(:users)

        expect(result).to be_a(String)
        expect(result).to eq("/health")
      end
    end
  end

  describe ".service_names" do
    it "returns array of registered service names" do
      result = described_class.service_names

      expect(result).to be_an(Array)
      expect(result).to include(:users)
      expect(result).to include(:appointments)
    end
  end

  describe "circuit breaker functionality" do
    describe ".allow_request?" do
      it "returns a boolean" do
        result = described_class.allow_request?(:users)

        expect([ true, false ]).to include(result)
      end
    end

    describe ".circuit_state" do
      it "returns a valid circuit state" do
        result = described_class.circuit_state(:users)

        expect([ :closed, :open, :half_open ]).to include(result)
      end
    end

    describe ".record_success" do
      it "does not raise error" do
        expect {
          described_class.record_success(:users)
        }.not_to raise_error
      end
    end

    describe ".record_failure" do
      it "does not raise error" do
        expect {
          described_class.record_failure(:users)
        }.not_to raise_error
      end
    end
  end
end
