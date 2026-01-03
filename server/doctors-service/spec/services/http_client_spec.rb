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
    it "defines default timeout" do
      expect(HttpClient::DEFAULT_TIMEOUT).to be_a(Integer)
    end

    it "defines retry statuses" do
      expect(HttpClient::RETRY_STATUSES).to include(408, 429, 500, 502, 503, 504)
    end

    it "defines retry exceptions" do
      expect(HttpClient::RETRY_EXCEPTIONS).to include(Faraday::TimeoutError)
      expect(HttpClient::RETRY_EXCEPTIONS).to include(Faraday::ConnectionFailed)
    end
  end

  describe "custom errors" do
    describe "ServiceUnavailable" do
      it "can be raised" do
        expect { raise HttpClient::ServiceUnavailable, "Service down" }
          .to raise_error(HttpClient::ServiceUnavailable, "Service down")
      end
    end

    describe "CircuitOpen" do
      it "can be raised" do
        expect { raise HttpClient::CircuitOpen, "Circuit is open" }
          .to raise_error(HttpClient::CircuitOpen, "Circuit is open")
      end
    end

    describe "RequestTimeout" do
      it "can be raised" do
        expect { raise HttpClient::RequestTimeout, "Timed out" }
          .to raise_error(HttpClient::RequestTimeout, "Timed out")
      end
    end

    describe "ClientError" do
      it "includes status and body" do
        error = HttpClient::ClientError.new("Bad request", status: 400, body: { error: "Invalid" })
        expect(error.status).to eq(400)
        expect(error.body).to eq({ error: "Invalid" })
      end
    end

    describe "ServerError" do
      it "includes status and body" do
        error = HttpClient::ServerError.new("Internal error", status: 500, body: { error: "Failure" })
        expect(error.status).to eq(500)
        expect(error.body).to eq({ error: "Failure" })
      end
    end
  end

  describe "Response" do
    let(:response) { HttpClient::Response.new(status: 200, body: { "key" => "value" }, headers: {}, duration_ms: 100) }

    describe "#success?" do
      it "returns true for 2xx status" do
        expect(HttpClient::Response.new(status: 200, body: {}, headers: {}).success?).to be true
        expect(HttpClient::Response.new(status: 201, body: {}, headers: {}).success?).to be true
        expect(HttpClient::Response.new(status: 299, body: {}, headers: {}).success?).to be true
      end

      it "returns false for non-2xx status" do
        expect(HttpClient::Response.new(status: 400, body: {}, headers: {}).success?).to be false
        expect(HttpClient::Response.new(status: 500, body: {}, headers: {}).success?).to be false
      end
    end

    describe "#redirect?" do
      it "returns true for 3xx status" do
        expect(HttpClient::Response.new(status: 301, body: {}, headers: {}).redirect?).to be true
        expect(HttpClient::Response.new(status: 302, body: {}, headers: {}).redirect?).to be true
      end
    end

    describe "#client_error?" do
      it "returns true for 4xx status" do
        expect(HttpClient::Response.new(status: 400, body: {}, headers: {}).client_error?).to be true
        expect(HttpClient::Response.new(status: 404, body: {}, headers: {}).client_error?).to be true
        expect(HttpClient::Response.new(status: 422, body: {}, headers: {}).client_error?).to be true
      end
    end

    describe "#server_error?" do
      it "returns true for 5xx status" do
        expect(HttpClient::Response.new(status: 500, body: {}, headers: {}).server_error?).to be true
        expect(HttpClient::Response.new(status: 503, body: {}, headers: {}).server_error?).to be true
      end
    end

    describe "#not_found?" do
      it "returns true for 404 status" do
        expect(HttpClient::Response.new(status: 404, body: {}, headers: {}).not_found?).to be true
        expect(HttpClient::Response.new(status: 200, body: {}, headers: {}).not_found?).to be false
      end
    end

    describe "#unauthorized?" do
      it "returns true for 401 status" do
        expect(HttpClient::Response.new(status: 401, body: {}, headers: {}).unauthorized?).to be true
      end
    end

    describe "#forbidden?" do
      it "returns true for 403 status" do
        expect(HttpClient::Response.new(status: 403, body: {}, headers: {}).forbidden?).to be true
      end
    end

    describe "#unprocessable?" do
      it "returns true for 422 status" do
        expect(HttpClient::Response.new(status: 422, body: {}, headers: {}).unprocessable?).to be true
      end
    end

    describe "#dig" do
      it "returns body for empty path" do
        expect(response.dig).to eq({ "key" => "value" })
      end

      it "digs into body hash" do
        nested_response = HttpClient::Response.new(
          status: 200,
          body: { "user" => { "name" => "John" } },
          headers: {}
        )
        expect(nested_response.dig(:user, :name)).to eq("John")
      end

      it "returns nil for non-hash body" do
        array_response = HttpClient::Response.new(status: 200, body: [], headers: {})
        expect(array_response.dig(:key)).to be_nil
      end
    end
  end

  describe "HTTP methods" do
    let(:service) { :users }
    let(:path) { "/internal/users/123" }

    before do
      stub_request(:any, /users-service/)
        .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })
    end

    describe ".get" do
      it "makes GET request" do
        response = HttpClient.get(service, path)

        expect(response).to be_a(HttpClient::Response)
        expect(response.success?).to be true
        expect(WebMock).to have_requested(:get, /users-service.*#{path}/)
      end

      it "includes query parameters" do
        HttpClient.get(service, path, params: { foo: "bar" })

        expect(WebMock).to have_requested(:get, /users-service/).with(query: { "foo" => "bar" })
      end
    end

    describe ".post" do
      it "makes POST request with body" do
        HttpClient.post(service, path, { name: "John" })

        expect(WebMock).to have_requested(:post, /users-service.*#{path}/)
          .with(body: { name: "John" }.to_json)
      end
    end

    describe ".put" do
      it "makes PUT request with body" do
        HttpClient.put(service, path, { name: "Jane" })

        expect(WebMock).to have_requested(:put, /users-service.*#{path}/)
          .with(body: { name: "Jane" }.to_json)
      end
    end

    describe ".patch" do
      it "makes PATCH request with body" do
        HttpClient.patch(service, path, { name: "Updated" })

        expect(WebMock).to have_requested(:patch, /users-service.*#{path}/)
          .with(body: { name: "Updated" }.to_json)
      end
    end

    describe ".delete" do
      it "makes DELETE request" do
        HttpClient.delete(service, path)

        expect(WebMock).to have_requested(:delete, /users-service.*#{path}/)
      end
    end
  end

  describe "request headers" do
    before do
      stub_request(:get, /users-service/)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "includes Content-Type header" do
      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "Content-Type" => "application/json" })
    end

    it "includes Accept header" do
      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "Accept" => "application/json" })
    end

    it "includes X-Internal-Service header" do
      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "X-Internal-Service" => "doctors-service" })
    end

    it "includes X-Request-ID header" do
      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "X-Request-ID" => /\S+/ })
    end

    it "includes custom headers" do
      HttpClient.get(:users, "/test", headers: { "X-Custom" => "value" })

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "X-Custom" => "value" })
    end

    it "includes auth token when set" do
      Thread.current[:auth_token] = "test-token"

      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "Authorization" => "Bearer test-token" })

      Thread.current[:auth_token] = nil
    end

    it "includes correlation ID when set" do
      Thread.current[:correlation_id] = "correlation-123"

      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "X-Correlation-ID" => "correlation-123" })

      Thread.current[:correlation_id] = nil
    end

    it "includes user ID when set" do
      Thread.current[:current_user_id] = "user-456"

      HttpClient.get(:users, "/test")

      expect(WebMock).to have_requested(:get, /users-service/)
        .with(headers: { "X-User-ID" => "user-456" })

      Thread.current[:current_user_id] = nil
    end
  end

  describe "error handling" do
    describe "circuit breaker integration" do
      before do
        # Use test_mode to simulate circuit open instead of mocking
        ServiceRegistry.test_allow_requests = false
      end

      it "raises CircuitOpen when circuit is open" do
        expect { HttpClient.get(:users, "/test") }
          .to raise_error(HttpClient::CircuitOpen, /Circuit breaker is open/)
      end
    end

    describe "timeout errors" do
      before do
        stub_request(:get, /users-service/)
          .to_timeout
      end

      it "raises RequestTimeout on timeout" do
        expect { HttpClient.get(:users, "/test") }
          .to raise_error(HttpClient::RequestTimeout, /timed out/)
      end

      it "handles timeout errors gracefully" do
        # In test mode, record_failure is a no-op but the timeout error is still raised
        expect { HttpClient.get(:users, "/test") }
          .to raise_error(HttpClient::RequestTimeout)
      end
    end

    describe "connection errors" do
      before do
        stub_request(:get, /users-service/)
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises ServiceUnavailable on connection failure" do
        expect { HttpClient.get(:users, "/test") }
          .to raise_error(HttpClient::ServiceUnavailable, /Cannot connect/)
      end

      it "handles connection errors gracefully" do
        # In test mode, record_failure is a no-op but the error is still raised
        expect { HttpClient.get(:users, "/test") }
          .to raise_error(HttpClient::ServiceUnavailable)
      end
    end

    describe "service not found" do
      it "raises ServiceNotFound for unknown service" do
        expect { HttpClient.get(:unknown, "/test") }
          .to raise_error(ServiceRegistry::ServiceNotFound)
      end
    end
  end

  describe "response parsing" do
    it "parses JSON response" do
      stub_request(:get, /users-service/)
        .to_return(
          status: 200,
          body: { "user" => { "name" => "John" } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      response = HttpClient.get(:users, "/test")

      expect(response.body).to eq({ "user" => { "name" => "John" } })
    end

    it "handles empty body" do
      stub_request(:get, /users-service/)
        .to_return(status: 204, body: "", headers: {})

      response = HttpClient.get(:users, "/test")

      expect(response.body).to eq({})
    end

    it "handles nil body" do
      stub_request(:get, /users-service/)
        .to_return(status: 204, body: nil, headers: {})

      response = HttpClient.get(:users, "/test")

      expect(response.body).to eq({})
    end

    it "handles non-JSON body" do
      stub_request(:get, /users-service/)
        .to_return(status: 200, body: "plain text", headers: { "Content-Type" => "text/plain" })

      response = HttpClient.get(:users, "/test")

      # The parse_body method returns symbol key for raw content
      expect(response.body).to eq({ raw: "plain text" })
      expect(response.body[:raw]).to eq("plain text")
    end
  end

  describe "logging" do
    before do
      stub_request(:get, /users-service/)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "logs request" do
      HttpClient.get(:users, "/test")

      expect(Rails.logger).to have_received(:info).with(/Request.*GET.*users/)
    end

    it "logs successful response" do
      HttpClient.get(:users, "/test")

      expect(Rails.logger).to have_received(:info).with(/Response.*GET.*status=200/)
    end

    it "logs response duration" do
      HttpClient.get(:users, "/test")

      expect(Rails.logger).to have_received(:info).with(/duration=\d+/)
    end

    context "with error response" do
      before do
        stub_request(:get, /users-service/)
          .to_return(status: 400, body: {}.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "logs warning for 4xx responses" do
        HttpClient.get(:users, "/test")

        expect(Rails.logger).to have_received(:warn).with(/Response.*status=400/)
      end
    end
  end

  describe ".health_check" do
    context "when service is healthy" do
      before do
        stub_request(:get, /users-service.*health/)
          .to_return(status: 200, body: { status: "ok" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns healthy status" do
        result = HttpClient.health_check(:users)

        expect(result[:status]).to eq("healthy")
        expect(result[:service]).to eq(:users)
        expect(result[:http_status]).to eq(200)
        expect(result[:response_time_ms]).to be_a(Numeric)
      end
    end

    context "when service returns non-retry error" do
      before do
        # Use 400 (not a retry status) to test unhealthy status
        stub_request(:get, /users-service.*health/)
          .to_return(status: 400, body: { status: "error" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns unhealthy status" do
        result = HttpClient.health_check(:users)

        expect(result[:status]).to eq("unhealthy")
        expect(result[:http_status]).to eq(400)
      end
    end

    context "when service returns retry error (503)" do
      before do
        # 503 is a retry status - after retries exhausted, it raises exception
        stub_request(:get, /users-service.*health/)
          .to_return(status: 503, body: { status: "error" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns error status after retries exhausted" do
        result = HttpClient.health_check(:users)

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
        result = HttpClient.health_check(:users)

        expect(result[:status]).to eq("circuit_open")
        expect(result[:circuit_state]).to eq(:open)
      end
    end

    context "when request fails" do
      before do
        stub_request(:get, /users-service.*health/)
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "returns error status" do
        result = HttpClient.health_check(:users)

        expect(result[:status]).to eq("error")
        expect(result[:error]).to be_present
      end
    end
  end

  describe ".health_check_all" do
    before do
      ServiceRegistry::SERVICES.keys.each do |service|
        stub_request(:get, /#{service}.*health/)
          .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })
      end
    end

    it "returns health check for all services" do
      results = HttpClient.health_check_all

      expect(results).to have_key(:users)
      expect(results).to have_key(:doctors)
      expect(results).to have_key(:appointments)
      expect(results).to have_key(:notifications)
      expect(results).to have_key(:payments)
    end
  end

  describe "custom timeout" do
    before do
      stub_request(:get, /users-service/)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "accepts custom timeout" do
      response = HttpClient.get(:users, "/test", timeout: 30)

      expect(response.success?).to be true
    end
  end
end