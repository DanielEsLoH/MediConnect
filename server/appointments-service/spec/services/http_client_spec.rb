# frozen_string_literal: true

require "rails_helper"

RSpec.describe HttpClient do
  before(:each) do
    # Enable test mode to bypass Redis entirely
    ServiceRegistry.test_mode = true
    ServiceRegistry.test_allow_requests = true
    ServiceRegistry.test_circuit_state = :closed

    # Logger mocks for tests that verify logging behavior
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  after(:each) do
    # Reset test mode after each example
    ServiceRegistry.reset_test_mode!
  end

  describe "constants" do
    it "has default timeout" do
      expect(described_class::DEFAULT_TIMEOUT).to eq(10)
    end

    it "has default open timeout" do
      expect(described_class::DEFAULT_OPEN_TIMEOUT).to eq(5)
    end

    it "has default max retries" do
      expect(described_class::DEFAULT_MAX_RETRIES).to eq(3)
    end

    it "has default retry interval" do
      expect(described_class::DEFAULT_RETRY_INTERVAL).to eq(0.5)
    end

    it "has retry statuses" do
      expect(described_class::RETRY_STATUSES).to include(408, 429, 500, 502, 503, 504)
    end

    it "has retry exceptions" do
      expect(described_class::RETRY_EXCEPTIONS).to include(
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        Errno::ECONNREFUSED
      )
    end
  end

  describe "exception classes" do
    it "has ServiceUnavailable as StandardError subclass" do
      expect(HttpClient::ServiceUnavailable.ancestors).to include(StandardError)
    end

    it "has CircuitOpen as StandardError subclass" do
      expect(HttpClient::CircuitOpen.ancestors).to include(StandardError)
    end

    it "has RequestTimeout as StandardError subclass" do
      expect(HttpClient::RequestTimeout.ancestors).to include(StandardError)
    end

    it "ClientError stores status and body" do
      error = HttpClient::ClientError.new("Bad request", status: 400, body: { error: "invalid" })

      expect(error.status).to eq(400)
      expect(error.body).to eq({ error: "invalid" })
      expect(error.message).to eq("Bad request")
    end

    it "ServerError stores status and body" do
      error = HttpClient::ServerError.new("Server error", status: 500, body: { error: "internal" })

      expect(error.status).to eq(500)
      expect(error.body).to eq({ error: "internal" })
      expect(error.message).to eq("Server error")
    end
  end

  describe ".get" do
    let(:base_url) { ServiceRegistry.url_for(:users) }
    let(:response_body) { { id: 1, name: "Test" } }

    context "with successful request" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success response" do
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_success
        expect(response.status).to eq(200)
      end

      it "parses JSON body" do
        response = described_class.get(:users, "/api/users/1")

        expect(response.body["id"]).to eq(1)
        expect(response.body["name"]).to eq("Test")
      end

      it "includes response headers" do
        response = described_class.get(:users, "/api/users/1")

        expect(response.headers).to be_present
      end

      it "includes duration_ms" do
        response = described_class.get(:users, "/api/users/1")

        expect(response.duration_ms).to be_a(Numeric)
        expect(response.duration_ms).to be >= 0
      end
    end

    context "with query parameters" do
      before do
        stub_request(:get, "#{base_url}/api/users")
          .with(query: { page: "1", per_page: "10" })
          .to_return(
            status: 200,
            body: { users: [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "forwards query parameters" do
        response = described_class.get(:users, "/api/users", params: { page: 1, per_page: 10 })

        expect(response).to be_success
      end
    end

    context "with custom headers" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .with(headers: { "X-Custom-Header" => "custom-value" })
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "forwards custom headers" do
        response = described_class.get(:users, "/api/users/1", headers: { "X-Custom-Header" => "custom-value" })

        expect(response).to be_success
      end
    end

    context "with custom timeout" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 200,
            body: response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "accepts custom timeout" do
        response = described_class.get(:users, "/api/users/1", timeout: 30)

        expect(response).to be_success
      end
    end

    context "with 404 response" do
      before do
        stub_request(:get, "#{base_url}/api/users/999")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns client error response" do
        response = described_class.get(:users, "/api/users/999")

        expect(response).to be_client_error
        expect(response).to be_not_found
        expect(response.status).to eq(404)
      end
    end

    context "with 401 response" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 401,
            body: { error: "Unauthorized" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns unauthorized response" do
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_unauthorized
        expect(response.status).to eq(401)
      end
    end

    context "with 403 response" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 403,
            body: { error: "Forbidden" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns forbidden response" do
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_forbidden
        expect(response.status).to eq(403)
      end
    end

    context "with 422 response" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 422,
            body: { errors: [ "Invalid data" ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns unprocessable response" do
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_unprocessable
        expect(response.status).to eq(422)
      end
    end

    context "with 500 response" do
      before do
        # 500 is a retry status, so after retries are exhausted it raises an exception
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 500,
            body: { error: "Internal error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises ServiceUnavailable after retries are exhausted" do
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::ServiceUnavailable)
      end
    end

    context "with 3xx redirect response" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 301,
            body: "",
            headers: { "Content-Type" => "application/json", "Location" => "/new-location" }
          )
      end

      it "returns redirect response" do
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_redirect
        expect(response.status).to eq(301)
      end
    end

    context "with timeout" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_timeout
      end

      it "raises RequestTimeout error" do
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::RequestTimeout)
      end

      it "handles timeout gracefully" do
        # In test mode, record_failure is a no-op but the timeout error is still raised
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::RequestTimeout)
      end
    end

    context "when service is unavailable (connection failed)" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises ServiceUnavailable error" do
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::ServiceUnavailable, /Cannot connect/)
      end

      it "handles connection failure gracefully" do
        # In test mode, record_failure is a no-op but the error is still raised
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::ServiceUnavailable)
      end
    end

    context "with unknown service" do
      it "raises ServiceNotFound error" do
        expect { described_class.get(:unknown_service, "/api/test") }
          .to raise_error(ServiceRegistry::ServiceNotFound)
      end
    end

    context "with empty response body" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 200,
            body: "",
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns empty hash for body" do
        response = described_class.get(:users, "/api/users/1")

        expect(response.body).to eq({})
      end
    end

    context "with nil response body" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 204,
            body: nil,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns empty hash for body" do
        response = described_class.get(:users, "/api/users/1")

        expect(response.body).to eq({})
      end
    end

    context "with non-JSON response body" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 200,
            body: "plain text response",
            headers: { "Content-Type" => "text/plain" }
          )
      end

      it "returns raw body in hash" do
        response = described_class.get(:users, "/api/users/1")

        # The parse_body method returns symbol key for raw content
        expect(response.body).to eq({ raw: "plain text response" })
        expect(response.body[:raw]).to eq("plain text response")
      end
    end
  end

  describe ".post" do
    let(:base_url) { ServiceRegistry.url_for(:appointments) }
    let(:request_body) { { patient_id: 1, doctor_id: 2 } }
    let(:response_body) { { id: 1, status: "created" } }

    context "with successful request" do
      before do
        stub_request(:post, "#{base_url}/api/appointments")
          .with(body: request_body.to_json)
          .to_return(
            status: 201,
            body: response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success response" do
        response = described_class.post(:appointments, "/api/appointments", request_body)

        expect(response).to be_success
        expect(response.status).to eq(201)
      end

      it "includes response body" do
        response = described_class.post(:appointments, "/api/appointments", request_body)

        expect(response.body["id"]).to eq(1)
        expect(response.body["status"]).to eq("created")
      end
    end

    context "with validation error" do
      before do
        stub_request(:post, "#{base_url}/api/appointments")
          .to_return(
            status: 422,
            body: { errors: [ "Doctor not available" ] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns client error response" do
        response = described_class.post(:appointments, "/api/appointments", request_body)

        expect(response).to be_client_error
        expect(response.status).to eq(422)
      end
    end

    context "with empty body" do
      before do
        stub_request(:post, "#{base_url}/api/test")
          .to_return(
            status: 200,
            body: { success: true }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "sends empty object" do
        response = described_class.post(:appointments, "/api/test", {})

        expect(response).to be_success
      end
    end

    context "with custom headers" do
      before do
        stub_request(:post, "#{base_url}/api/appointments")
          .with(headers: { "X-Custom" => "value" })
          .to_return(
            status: 201,
            body: response_body.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "forwards custom headers" do
        response = described_class.post(:appointments, "/api/appointments", request_body, headers: { "X-Custom" => "value" })

        expect(response).to be_success
      end
    end
  end

  describe ".put" do
    let(:base_url) { ServiceRegistry.url_for(:users) }
    let(:request_body) { { name: "Updated Name" } }

    context "with successful request" do
      before do
        stub_request(:put, "#{base_url}/api/users/1")
          .with(body: request_body.to_json)
          .to_return(
            status: 200,
            body: { id: 1, name: "Updated Name" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success response" do
        response = described_class.put(:users, "/api/users/1", request_body)

        expect(response).to be_success
      end
    end
  end

  describe ".patch" do
    let(:base_url) { ServiceRegistry.url_for(:users) }
    let(:request_body) { { name: "Patched Name" } }

    context "with successful request" do
      before do
        stub_request(:patch, "#{base_url}/api/users/1")
          .with(body: request_body.to_json)
          .to_return(
            status: 200,
            body: { id: 1, name: "Patched Name" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success response" do
        response = described_class.patch(:users, "/api/users/1", request_body)

        expect(response).to be_success
      end
    end
  end

  describe ".delete" do
    let(:base_url) { ServiceRegistry.url_for(:appointments) }

    context "with successful request" do
      before do
        stub_request(:delete, "#{base_url}/api/appointments/1")
          .to_return(
            status: 204,
            body: "",
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success response" do
        response = described_class.delete(:appointments, "/api/appointments/1")

        expect(response).to be_success
        expect(response.status).to eq(204)
      end
    end

    context "with not found response" do
      before do
        stub_request(:delete, "#{base_url}/api/appointments/999")
          .to_return(
            status: 404,
            body: { error: "Not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns client error response" do
        response = described_class.delete(:appointments, "/api/appointments/999")

        expect(response).to be_client_error
        expect(response).to be_not_found
      end
    end
  end

  describe ".health_check" do
    let(:base_url) { ServiceRegistry.url_for(:users) }

    context "when service is healthy" do
      before do
        stub_request(:get, "#{base_url}/health")
          .to_return(
            status: 200,
            body: { status: "ok" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns healthy status" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("healthy")
      end

      it "includes response time" do
        result = described_class.health_check(:users)

        expect(result[:response_time_ms]).to be_a(Numeric)
        expect(result[:response_time_ms]).to be >= 0
      end

      it "includes http status" do
        result = described_class.health_check(:users)

        expect(result[:http_status]).to eq(200)
      end

      it "includes circuit state" do
        result = described_class.health_check(:users)

        expect(result[:circuit_state]).to eq(:closed)
      end
    end

    context "when service returns non-retry error" do
      before do
        # Use 400 (not a retry status) to test unhealthy status
        stub_request(:get, "#{base_url}/health")
          .to_return(
            status: 400,
            body: { status: "error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns unhealthy status" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("unhealthy")
        expect(result[:http_status]).to eq(400)
      end
    end

    context "when service returns retry error (503)" do
      before do
        allow(ServiceRegistry).to receive(:record_failure)
        # 503 is a retry status - after retries exhausted, it raises exception
        stub_request(:get, "#{base_url}/health")
          .to_return(
            status: 503,
            body: { status: "error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns error status after retries exhausted" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("error")
        expect(result[:error]).to be_present
      end
    end

    context "when circuit is open" do
      before do
        # Use test_mode to simulate circuit open
        ServiceRegistry.test_allow_requests = false
        ServiceRegistry.test_circuit_state = :open
      end

      it "returns circuit_open status" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("circuit_open")
        expect(result[:circuit_state]).to eq(:open)
        expect(result[:response_time_ms]).to be_nil
      end
    end

    context "when service is unreachable" do
      before do
        stub_request(:get, "#{base_url}/health")
          .to_timeout
      end

      it "returns error with message" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("error")
        expect(result[:error]).to be_present
        expect(result[:http_status]).to be_nil
      end
    end
  end

  describe ".health_check_all" do
    before do
      ServiceRegistry.service_names.each do |service|
        url = ServiceRegistry.url_for(service)
        stub_request(:get, "#{url}/health")
          .to_return(
            status: 200,
            body: { status: "ok" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end
    end

    it "returns health status for all services" do
      results = described_class.health_check_all

      ServiceRegistry.service_names.each do |service|
        expect(results).to have_key(service)
        expect(results[service][:status]).to eq("healthy")
      end
    end
  end

  describe "circuit breaker integration" do
    let(:base_url) { ServiceRegistry.url_for(:users) }

    context "when circuit is open" do
      before do
        # Use test_mode to simulate circuit open
        ServiceRegistry.test_allow_requests = false
      end

      it "raises CircuitOpen error" do
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::CircuitOpen, /Circuit breaker is open/)
      end
    end

    context "on successful request" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 200,
            body: { id: 1 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "completes successfully" do
        # In test mode, record_success is a no-op but request completes
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_success
      end
    end

    context "on failed request" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_timeout
      end

      it "raises RequestTimeout error" do
        # In test mode, record_failure is a no-op but the timeout error is still raised
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::RequestTimeout)
      end
    end

    context "on general error" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_raise(StandardError.new("Unexpected error"))
      end

      it "raises ServiceUnavailable" do
        # In test mode, record_failure is a no-op but the error is still raised
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(described_class::ServiceUnavailable, /unavailable/)
      end
    end
  end

  describe "Response class" do
    describe "#success?" do
      it "returns true for 2xx status" do
        (200..299).each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).to be_success, "Expected status #{status} to be success"
        end
      end

      it "returns false for non-2xx status" do
        [ 199, 300, 400, 500 ].each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).not_to be_success, "Expected status #{status} not to be success"
        end
      end
    end

    describe "#redirect?" do
      it "returns true for 3xx status" do
        (300..399).each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).to be_redirect, "Expected status #{status} to be redirect"
        end
      end

      it "returns false for non-3xx status" do
        [ 200, 299, 400, 500 ].each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).not_to be_redirect, "Expected status #{status} not to be redirect"
        end
      end
    end

    describe "#client_error?" do
      it "returns true for 4xx status" do
        [ 400, 401, 403, 404, 422, 429, 499 ].each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).to be_client_error, "Expected status #{status} to be client_error"
        end
      end

      it "returns false for non-4xx status" do
        [ 200, 301, 399, 500 ].each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).not_to be_client_error, "Expected status #{status} not to be client_error"
        end
      end
    end

    describe "#server_error?" do
      it "returns true for 5xx status" do
        [ 500, 502, 503, 504, 599 ].each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).to be_server_error, "Expected status #{status} to be server_error"
        end
      end

      it "returns false for non-5xx status" do
        [ 200, 301, 400, 499 ].each do |status|
          response = described_class::Response.new(status: status, body: {}, headers: {})
          expect(response).not_to be_server_error, "Expected status #{status} not to be server_error"
        end
      end
    end

    describe "#not_found?" do
      it "returns true for 404 status" do
        response = described_class::Response.new(status: 404, body: {}, headers: {})
        expect(response).to be_not_found
      end

      it "returns false for other statuses" do
        response = described_class::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_not_found
      end
    end

    describe "#unauthorized?" do
      it "returns true for 401 status" do
        response = described_class::Response.new(status: 401, body: {}, headers: {})
        expect(response).to be_unauthorized
      end

      it "returns false for other statuses" do
        response = described_class::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_unauthorized
      end
    end

    describe "#forbidden?" do
      it "returns true for 403 status" do
        response = described_class::Response.new(status: 403, body: {}, headers: {})
        expect(response).to be_forbidden
      end

      it "returns false for other statuses" do
        response = described_class::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_forbidden
      end
    end

    describe "#unprocessable?" do
      it "returns true for 422 status" do
        response = described_class::Response.new(status: 422, body: {}, headers: {})
        expect(response).to be_unprocessable
      end

      it "returns false for other statuses" do
        response = described_class::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_unprocessable
      end
    end

    describe "#dig" do
      it "returns body if no path provided" do
        response = described_class::Response.new(status: 200, body: { foo: "bar" }, headers: {})
        expect(response.dig).to eq({ foo: "bar" })
      end

      it "returns nil if body is not a hash" do
        response = described_class::Response.new(status: 200, body: "string", headers: {})
        expect(response.dig(:foo)).to be_nil
      end

      it "digs into body hash" do
        response = described_class::Response.new(
          status: 200,
          body: { "user" => { "name" => "John" } },
          headers: {}
        )
        expect(response.dig(:user, :name)).to eq("John")
      end

      it "returns nil for missing keys" do
        response = described_class::Response.new(
          status: 200,
          body: { "user" => { "name" => "John" } },
          headers: {}
        )
        expect(response.dig(:user, :email)).to be_nil
      end
    end

    describe "#duration_ms" do
      it "returns provided duration" do
        response = described_class::Response.new(status: 200, body: {}, headers: {}, duration_ms: 123.45)
        expect(response.duration_ms).to eq(123.45)
      end

      it "defaults to 0" do
        response = described_class::Response.new(status: 200, body: {}, headers: {})
        expect(response.duration_ms).to eq(0)
      end
    end
  end

  describe "default headers" do
    let(:base_url) { ServiceRegistry.url_for(:users) }

    before do
      stub_request(:get, "#{base_url}/api/test")
        .to_return(
          status: 200,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "includes Content-Type header" do
      described_class.get(:users, "/api/test")

      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "Content-Type" => "application/json" })).to have_been_made
    end

    it "includes Accept header" do
      described_class.get(:users, "/api/test")

      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "Accept" => "application/json" })).to have_been_made
    end

    it "includes User-Agent header" do
      described_class.get(:users, "/api/test")

      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "User-Agent" => "MediConnect-AppointmentsService/1.0" })).to have_been_made
    end

    it "includes X-Internal-Service header" do
      described_class.get(:users, "/api/test")

      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "X-Internal-Service" => "appointments-service" })).to have_been_made
    end

    it "includes X-Service-Version header" do
      described_class.get(:users, "/api/test")

      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "X-Service-Version" => "1.0" })).to have_been_made
    end

    it "includes X-Request-ID header" do
      described_class.get(:users, "/api/test")

      # Note: WebMock normalizes header names, so X-Request-ID becomes X-Request-Id
      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "X-Request-Id" => /\S+/ })).to have_been_made
    end

    context "with thread-local auth token" do
      before do
        Thread.current[:auth_token] = "test-token"
      end

      after do
        Thread.current[:auth_token] = nil
      end

      it "includes Authorization header" do
        described_class.get(:users, "/api/test")

        expect(a_request(:get, "#{base_url}/api/test")
          .with(headers: { "Authorization" => "Bearer test-token" })).to have_been_made
      end
    end

    context "with thread-local user id" do
      before do
        Thread.current[:current_user_id] = "user-123"
      end

      after do
        Thread.current[:current_user_id] = nil
      end

      it "includes X-User-ID header" do
        described_class.get(:users, "/api/test")

        expect(a_request(:get, "#{base_url}/api/test")
          .with(headers: { "X-User-ID" => "user-123" })).to have_been_made
      end
    end

    context "with thread-local correlation id" do
      before do
        Thread.current[:correlation_id] = "corr-123"
      end

      after do
        Thread.current[:correlation_id] = nil
      end

      it "includes X-Correlation-ID header" do
        described_class.get(:users, "/api/test")

        expect(a_request(:get, "#{base_url}/api/test")
          .with(headers: { "X-Correlation-ID" => "corr-123" })).to have_been_made
      end
    end
  end
end
