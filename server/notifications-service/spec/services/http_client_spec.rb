# frozen_string_literal: true

require "rails_helper"

RSpec.describe HttpClient do
  let(:service_name) { :users }
  let(:path) { "/internal/users/123" }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe "Response class" do
    let(:response) { described_class::Response.new(status: 200, body: { "key" => "value" }, headers: {}) }

    describe "#success?" do
      it "returns true for 2xx status" do
        expect(response.success?).to be true
      end

      it "returns false for 4xx status" do
        error_response = described_class::Response.new(status: 404, body: {}, headers: {})
        expect(error_response.success?).to be false
      end
    end

    describe "#redirect?" do
      it "returns true for 3xx status" do
        redirect_response = described_class::Response.new(status: 302, body: {}, headers: {})
        expect(redirect_response.redirect?).to be true
      end

      it "returns false for non-3xx status" do
        expect(response.redirect?).to be false
      end
    end

    describe "#client_error?" do
      it "returns true for 4xx status" do
        error_response = described_class::Response.new(status: 400, body: {}, headers: {})
        expect(error_response.client_error?).to be true
      end

      it "returns false for non-4xx status" do
        expect(response.client_error?).to be false
      end
    end

    describe "#server_error?" do
      it "returns true for 5xx status" do
        error_response = described_class::Response.new(status: 500, body: {}, headers: {})
        expect(error_response.server_error?).to be true
      end

      it "returns false for non-5xx status" do
        expect(response.server_error?).to be false
      end
    end

    describe "#not_found?" do
      it "returns true for 404 status" do
        not_found = described_class::Response.new(status: 404, body: {}, headers: {})
        expect(not_found.not_found?).to be true
      end

      it "returns false for other status" do
        expect(response.not_found?).to be false
      end
    end

    describe "#unauthorized?" do
      it "returns true for 401 status" do
        unauthorized = described_class::Response.new(status: 401, body: {}, headers: {})
        expect(unauthorized.unauthorized?).to be true
      end

      it "returns false for other status" do
        expect(response.unauthorized?).to be false
      end
    end

    describe "#forbidden?" do
      it "returns true for 403 status" do
        forbidden = described_class::Response.new(status: 403, body: {}, headers: {})
        expect(forbidden.forbidden?).to be true
      end

      it "returns false for other status" do
        expect(response.forbidden?).to be false
      end
    end

    describe "#unprocessable?" do
      it "returns true for 422 status" do
        unprocessable = described_class::Response.new(status: 422, body: {}, headers: {})
        expect(unprocessable.unprocessable?).to be true
      end

      it "returns false for other status" do
        expect(response.unprocessable?).to be false
      end
    end

    describe "#dig" do
      let(:nested_response) do
        described_class::Response.new(
          status: 200,
          body: { "user" => { "email" => "test@example.com" } },
          headers: {}
        )
      end

      it "digs into nested body" do
        expect(nested_response.dig("user", "email")).to eq("test@example.com")
      end

      it "returns body for empty path" do
        expect(nested_response.dig).to eq({ "user" => { "email" => "test@example.com" } })
      end

      it "returns nil for non-hash body" do
        array_response = described_class::Response.new(status: 200, body: ["item"], headers: {})
        expect(array_response.dig("key")).to be_nil
      end

      it "returns nil for non-existent path" do
        expect(nested_response.dig("nonexistent", "path")).to be_nil
      end
    end

    describe "#duration_ms" do
      it "stores duration in milliseconds" do
        timed_response = described_class::Response.new(
          status: 200,
          body: {},
          headers: {},
          duration_ms: 150.5
        )
        expect(timed_response.duration_ms).to eq(150.5)
      end

      it "defaults to 0" do
        expect(response.duration_ms).to eq(0)
      end
    end
  end

  describe "constants" do
    it "has DEFAULT_TIMEOUT" do
      expect(described_class::DEFAULT_TIMEOUT).to be_a(Integer)
      expect(described_class::DEFAULT_TIMEOUT).to be > 0
    end

    it "has DEFAULT_OPEN_TIMEOUT" do
      expect(described_class::DEFAULT_OPEN_TIMEOUT).to be_a(Integer)
      expect(described_class::DEFAULT_OPEN_TIMEOUT).to be > 0
    end

    it "has DEFAULT_MAX_RETRIES" do
      expect(described_class::DEFAULT_MAX_RETRIES).to be_a(Integer)
    end

    it "has DEFAULT_RETRY_INTERVAL" do
      expect(described_class::DEFAULT_RETRY_INTERVAL).to be_a(Numeric)
    end

    it "has RETRY_STATUSES with retriable HTTP status codes" do
      expect(described_class::RETRY_STATUSES).to include(500, 502, 503, 504)
      expect(described_class::RETRY_STATUSES).to include(408) # Request Timeout
      expect(described_class::RETRY_STATUSES).to include(429) # Too Many Requests
    end

    it "has RETRY_EXCEPTIONS with retriable exception types" do
      expect(described_class::RETRY_EXCEPTIONS).to include(Faraday::TimeoutError)
      expect(described_class::RETRY_EXCEPTIONS).to include(Faraday::ConnectionFailed)
      expect(described_class::RETRY_EXCEPTIONS).to include(Errno::ECONNREFUSED)
    end
  end

  describe "custom exceptions" do
    describe "ServiceUnavailable" do
      it "is a subclass of StandardError" do
        expect(described_class::ServiceUnavailable).to be < StandardError
      end

      it "can be instantiated with a message" do
        error = described_class::ServiceUnavailable.new("Service down")
        expect(error.message).to eq("Service down")
      end
    end

    describe "CircuitOpen" do
      it "is a subclass of StandardError" do
        expect(described_class::CircuitOpen).to be < StandardError
      end

      it "can be instantiated with a message" do
        error = described_class::CircuitOpen.new("Circuit is open")
        expect(error.message).to eq("Circuit is open")
      end
    end

    describe "RequestTimeout" do
      it "is a subclass of StandardError" do
        expect(described_class::RequestTimeout).to be < StandardError
      end
    end

    describe "ClientError" do
      it "stores status and body" do
        error = described_class::ClientError.new("Bad request", status: 400, body: { error: "Invalid" })

        expect(error.message).to eq("Bad request")
        expect(error.status).to eq(400)
        expect(error.body).to eq({ error: "Invalid" })
      end

      it "defaults status and body to nil" do
        error = described_class::ClientError.new("Error")

        expect(error.status).to be_nil
        expect(error.body).to be_nil
      end
    end

    describe "ServerError" do
      it "stores status and body" do
        error = described_class::ServerError.new("Internal error", status: 500, body: { error: "Server error" })

        expect(error.message).to eq("Internal error")
        expect(error.status).to eq(500)
        expect(error.body).to eq({ error: "Server error" })
      end

      it "defaults status and body to nil" do
        error = described_class::ServerError.new("Error")

        expect(error.status).to be_nil
        expect(error.body).to be_nil
      end
    end
  end

  describe "class methods" do
    describe ".get" do
      it "responds to get" do
        expect(described_class).to respond_to(:get)
      end
    end

    describe ".post" do
      it "responds to post" do
        expect(described_class).to respond_to(:post)
      end
    end

    describe ".put" do
      it "responds to put" do
        expect(described_class).to respond_to(:put)
      end
    end

    describe ".patch" do
      it "responds to patch" do
        expect(described_class).to respond_to(:patch)
      end
    end

    describe ".delete" do
      it "responds to delete" do
        expect(described_class).to respond_to(:delete)
      end
    end

    describe ".health_check" do
      it "responds to health_check" do
        expect(described_class).to respond_to(:health_check)
      end
    end

    describe ".health_check_all" do
      it "responds to health_check_all" do
        expect(described_class).to respond_to(:health_check_all)
      end
    end
  end

  describe "circuit breaker integration" do
    context "when circuit is open" do
      before do
        allow(ServiceRegistry).to receive(:allow_request?).with(service_name).and_return(false)
        allow(ServiceRegistry).to receive(:url_for).with(service_name).and_return("http://test:3000")
      end

      it "raises an error when circuit is open" do
        # The implementation raises CircuitOpen which gets caught and re-raised as ServiceUnavailable
        expect {
          described_class.get(service_name, path)
        }.to raise_error(described_class::ServiceUnavailable, /Circuit breaker is open/)
      end

      it "does not make HTTP request when circuit is open" do
        expect(Faraday).not_to receive(:new)

        begin
          described_class.get(service_name, path)
        rescue described_class::ServiceUnavailable
          # Expected
        end
      end
    end
  end
end
