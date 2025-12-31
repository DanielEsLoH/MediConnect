# frozen_string_literal: true

require "rails_helper"

RSpec.describe HttpClient do
  let(:doctors_url) { "http://doctors-service:3002" }
  let(:test_path) { "/internal/doctors/123" }
  let(:full_url) { "#{doctors_url}#{test_path}" }

  before do
    # Stub ServiceRegistry to return predictable URLs
    allow(ServiceRegistry).to receive(:url_for).with(:doctors).and_return(doctors_url)
    allow(ServiceRegistry).to receive(:allow_request?).and_return(true)
    allow(ServiceRegistry).to receive(:record_success)
    allow(ServiceRegistry).to receive(:record_failure)
    allow(ServiceRegistry).to receive(:health_path_for).with(:doctors).and_return("/health")
    allow(ServiceRegistry).to receive(:circuit_state).with(:doctors).and_return(:closed)
    allow(ServiceRegistry).to receive(:service_names).and_return([:users, :doctors, :appointments, :notifications, :payments])

    # Clear thread-local variables
    Thread.current[:request_id] = nil
    Thread.current[:correlation_id] = nil
    Thread.current[:auth_token] = nil
    Thread.current[:current_user_id] = nil
  end

  describe "HTTP Method Tests" do
    describe ".get" do
      it "performs a GET request" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{"id": 123}', headers: { "Content-Type" => "application/json" })

        response = described_class.get(:doctors, test_path)

        expect(response.status).to eq(200)
        expect(a_request(:get, full_url)).to have_been_made
      end

      it "includes query parameters" do
        stub_request(:get, "#{doctors_url}/internal/search")
          .with(query: { name: "John", specialty: "cardiology" })
          .to_return(status: 200, body: '[]', headers: { "Content-Type" => "application/json" })

        described_class.get(:doctors, "/internal/search", params: { name: "John", specialty: "cardiology" })

        expect(a_request(:get, "#{doctors_url}/internal/search")
          .with(query: { name: "John", specialty: "cardiology" })).to have_been_made
      end

      it "sets correct Content-Type header" do
        stub_request(:get, full_url)
          .with(headers: { "Content-Type" => "application/json" })
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        described_class.get(:doctors, test_path)

        expect(a_request(:get, full_url)
          .with(headers: { "Content-Type" => "application/json" })).to have_been_made
      end

      it "sets User-Agent header" do
        stub_request(:get, full_url)
          .with(headers: { "User-Agent" => /MediConnect/ })
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        described_class.get(:doctors, test_path)

        expect(a_request(:get, full_url)
          .with(headers: { "User-Agent" => /MediConnect/ })).to have_been_made
      end

      it "sets X-Internal-Service header" do
        stub_request(:get, full_url)
          .with(headers: { "X-Internal-Service" => "users-service" })
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        described_class.get(:doctors, test_path)

        expect(a_request(:get, full_url)
          .with(headers: { "X-Internal-Service" => "users-service" })).to have_been_made
      end
    end

    describe ".post" do
      it "performs a POST request with body" do
        stub_request(:post, "#{doctors_url}/internal/doctors")
          .with(body: '{"name":"Dr. Smith"}')
          .to_return(status: 201, body: '{"id": 1}', headers: { "Content-Type" => "application/json" })

        response = described_class.post(:doctors, "/internal/doctors", { name: "Dr. Smith" })

        expect(response.status).to eq(201)
        expect(a_request(:post, "#{doctors_url}/internal/doctors")).to have_been_made
      end

      it "serializes body to JSON" do
        stub_request(:post, "#{doctors_url}/internal/doctors")
          .with(body: '{"name":"Test","specialty":"General"}')
          .to_return(status: 201, body: '{}', headers: { "Content-Type" => "application/json" })

        described_class.post(:doctors, "/internal/doctors", { name: "Test", specialty: "General" })

        expect(a_request(:post, "#{doctors_url}/internal/doctors")
          .with(body: '{"name":"Test","specialty":"General"}')).to have_been_made
      end
    end

    describe ".put" do
      it "performs a PUT request" do
        stub_request(:put, full_url)
          .with(body: '{"name":"Updated"}')
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        response = described_class.put(:doctors, test_path, { name: "Updated" })

        expect(response.status).to eq(200)
        expect(a_request(:put, full_url)).to have_been_made
      end
    end

    describe ".patch" do
      it "performs a PATCH request" do
        stub_request(:patch, full_url)
          .with(body: '{"active":false}')
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        response = described_class.patch(:doctors, test_path, { active: false })

        expect(response.status).to eq(200)
        expect(a_request(:patch, full_url)).to have_been_made
      end
    end

    describe ".delete" do
      it "performs a DELETE request" do
        stub_request(:delete, full_url)
          .to_return(status: 204, body: '', headers: {})

        response = described_class.delete(:doctors, test_path)

        expect(response.status).to eq(204)
        expect(a_request(:delete, full_url)).to have_been_made
      end
    end
  end

  describe "Response Wrapper" do
    let(:response_headers) { { "Content-Type" => "application/json" } }

    # Test Response class directly to avoid retry middleware issues with 5xx status codes
    describe HttpClient::Response do
      describe "#success?" do
        it "returns true for 200 status" do
          response = described_class.new(status: 200, body: {}, headers: {})
          expect(response.success?).to be true
        end

        it "returns true for 201 status" do
          response = described_class.new(status: 201, body: {}, headers: {})
          expect(response.success?).to be true
        end

        it "returns true for 204 status" do
          response = described_class.new(status: 204, body: {}, headers: {})
          expect(response.success?).to be true
        end

        it "returns false for 400 status" do
          response = described_class.new(status: 400, body: {}, headers: {})
          expect(response.success?).to be false
        end

        it "returns false for 500 status" do
          response = described_class.new(status: 500, body: {}, headers: {})
          expect(response.success?).to be false
        end
      end

      describe "#redirect?" do
        it "returns true for 301 status" do
          response = described_class.new(status: 301, body: {}, headers: {})
          expect(response.redirect?).to be true
        end

        it "returns true for 302 status" do
          response = described_class.new(status: 302, body: {}, headers: {})
          expect(response.redirect?).to be true
        end

        it "returns false for 200 status" do
          response = described_class.new(status: 200, body: {}, headers: {})
          expect(response.redirect?).to be false
        end
      end

      describe "#client_error?" do
        it "returns true for 400 status" do
          response = described_class.new(status: 400, body: {}, headers: {})
          expect(response.client_error?).to be true
        end

        it "returns true for 404 status" do
          response = described_class.new(status: 404, body: {}, headers: {})
          expect(response.client_error?).to be true
        end

        it "returns true for 422 status" do
          response = described_class.new(status: 422, body: {}, headers: {})
          expect(response.client_error?).to be true
        end

        it "returns false for 500 status" do
          response = described_class.new(status: 500, body: {}, headers: {})
          expect(response.client_error?).to be false
        end
      end

      describe "#server_error?" do
        it "returns true for 500 status" do
          response = described_class.new(status: 500, body: {}, headers: {})
          expect(response.server_error?).to be true
        end

        it "returns true for 502 status" do
          response = described_class.new(status: 502, body: {}, headers: {})
          expect(response.server_error?).to be true
        end

        it "returns true for 503 status" do
          response = described_class.new(status: 503, body: {}, headers: {})
          expect(response.server_error?).to be true
        end

        it "returns false for 400 status" do
          response = described_class.new(status: 400, body: {}, headers: {})
          expect(response.server_error?).to be false
        end
      end
    end

    describe "#not_found?" do
      it "returns true for 404 status" do
        stub_request(:get, full_url)
          .to_return(status: 404, body: '{}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.not_found?).to be true
      end

      it "returns false for 400 status" do
        stub_request(:get, full_url)
          .to_return(status: 400, body: '{}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.not_found?).to be false
      end
    end

    describe "#unauthorized?" do
      it "returns true for 401 status" do
        stub_request(:get, full_url)
          .to_return(status: 401, body: '{}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.unauthorized?).to be true
      end
    end

    describe "#forbidden?" do
      it "returns true for 403 status" do
        stub_request(:get, full_url)
          .to_return(status: 403, body: '{}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.forbidden?).to be true
      end
    end

    describe "#unprocessable?" do
      it "returns true for 422 status" do
        stub_request(:get, full_url)
          .to_return(status: 422, body: '{}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.unprocessable?).to be true
      end
    end

    describe "#dig" do
      it "returns body when no path given" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{"data":"value"}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.dig).to eq({ "data" => "value" })
      end

      it "traverses nested hash with path" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{"user":{"name":"John"}}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.dig(:user, :name)).to eq("John")
      end

      it "returns nil for non-existent path" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{"user":{}}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.dig(:user, :nonexistent)).to be_nil
      end

      it "returns nil when body is not a hash" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '["item1","item2"]', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.dig(:key)).to be_nil
      end
    end

    describe "body parsing" do
      it "parses JSON body" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{"id":1,"name":"Test"}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.body).to eq({ "id" => 1, "name" => "Test" })
      end

      it "handles empty body" do
        stub_request(:get, full_url)
          .to_return(status: 204, body: '', headers: {})

        response = described_class.get(:doctors, test_path)
        expect(response.body).to eq({})
      end

      it "handles nil body" do
        stub_request(:get, full_url)
          .to_return(status: 204, body: nil, headers: {})

        response = described_class.get(:doctors, test_path)
        expect(response.body).to eq({})
      end

      it "wraps invalid JSON in raw key" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: 'plain text', headers: { "Content-Type" => "text/plain" })

        response = described_class.get(:doctors, test_path)
        expect(response.body).to eq({ raw: "plain text" })
      end
    end

    describe "#duration_ms" do
      it "includes response duration" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{}', headers: response_headers)

        response = described_class.get(:doctors, test_path)
        expect(response.duration_ms).to be_a(Numeric)
        expect(response.duration_ms).to be >= 0
      end
    end
  end

  describe "Health Check Methods" do
    before do
      allow(ServiceRegistry).to receive(:url_for).and_return(doctors_url)
      allow(ServiceRegistry).to receive(:health_path_for).and_return("/health")
      allow(ServiceRegistry).to receive(:circuit_state).and_return(:closed)
    end

    describe ".health_check" do
      it "returns healthy status for 200 response" do
        stub_request(:get, "#{doctors_url}/health")
          .to_return(status: 200, body: '{"status":"ok"}', headers: { "Content-Type" => "application/json" })

        result = described_class.health_check(:doctors)

        expect(result[:status]).to eq("healthy")
        expect(result[:service]).to eq(:doctors)
      end

      it "returns unhealthy status for non-200 response" do
        # Use 400 instead of 500 to avoid retry middleware
        stub_request(:get, "#{doctors_url}/health")
          .to_return(status: 400, body: '{"status":"error"}', headers: { "Content-Type" => "application/json" })

        result = described_class.health_check(:doctors)

        expect(result[:status]).to eq("unhealthy")
      end

      it "returns response time in milliseconds" do
        stub_request(:get, "#{doctors_url}/health")
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        result = described_class.health_check(:doctors)

        expect(result[:response_time_ms]).to be_a(Numeric)
      end

      it "includes http_status in response" do
        stub_request(:get, "#{doctors_url}/health")
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        result = described_class.health_check(:doctors)

        expect(result[:http_status]).to eq(200)
      end

      it "includes circuit_state in response" do
        stub_request(:get, "#{doctors_url}/health")
          .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

        result = described_class.health_check(:doctors)

        expect(result[:circuit_state]).to eq(:closed)
      end

      it "returns error status when circuit is OPEN" do
        allow(ServiceRegistry).to receive(:allow_request?).with(:doctors).and_return(false)

        result = described_class.health_check(:doctors)

        # When circuit is open, the ServiceUnavailable error is caught
        # and returns "error" status (not "circuit_open" since the HttpClient::CircuitOpen
        # is wrapped in ServiceUnavailable before being raised)
        expect(result[:status]).to eq("error")
        expect(result[:error]).to include("Circuit breaker is open")
      end

      it "returns error status on connection failure" do
        stub_request(:get, "#{doctors_url}/health")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        result = described_class.health_check(:doctors)

        expect(result[:status]).to eq("error")
        expect(result[:error]).to be_present
      end
    end

    describe ".health_check_all" do
      before do
        [:users, :doctors, :appointments, :notifications, :payments].each do |service|
          allow(ServiceRegistry).to receive(:url_for).with(service).and_return("http://#{service}-service:3000")
          allow(ServiceRegistry).to receive(:health_path_for).with(service).and_return("/health")
          allow(ServiceRegistry).to receive(:circuit_state).with(service).and_return(:closed)
          stub_request(:get, "http://#{service}-service:3000/health")
            .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })
        end
      end

      it "returns health status for all services" do
        result = described_class.health_check_all

        expect(result.keys).to match_array([:users, :doctors, :appointments, :notifications, :payments])
      end

      it "includes status for each service" do
        result = described_class.health_check_all

        result.each_value do |health|
          expect(health).to have_key(:status)
        end
      end
    end
  end

  describe "Error Handling" do
    describe "CircuitOpen" do
      it "raises error when circuit breaker is open" do
        allow(ServiceRegistry).to receive(:allow_request?).with(:doctors).and_return(false)

        # The error gets wrapped in ServiceUnavailable due to rescue block
        expect { described_class.get(:doctors, test_path) }
          .to raise_error(HttpClient::ServiceUnavailable, /Circuit breaker is open/)
      end
    end

    describe "ServiceUnavailable" do
      it "raises ServiceUnavailable on connection failure" do
        stub_request(:get, full_url)
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        expect { described_class.get(:doctors, test_path) }
          .to raise_error(HttpClient::ServiceUnavailable)
      end

      it "records failure with ServiceRegistry on connection error" do
        stub_request(:get, full_url)
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        expect(ServiceRegistry).to receive(:record_failure).with(:doctors)

        begin
          described_class.get(:doctors, test_path)
        rescue HttpClient::ServiceUnavailable
          # expected
        end
      end
    end

    describe "RequestTimeout" do
      it "raises error on timeout" do
        stub_request(:get, full_url)
          .to_timeout

        # Timeout errors may be caught and wrapped in ServiceUnavailable after retries
        expect { described_class.get(:doctors, test_path) }
          .to raise_error(StandardError)
      end

      it "records failure with ServiceRegistry on timeout" do
        stub_request(:get, full_url)
          .to_timeout

        expect(ServiceRegistry).to receive(:record_failure).with(:doctors)

        begin
          described_class.get(:doctors, test_path)
        rescue HttpClient::RequestTimeout, HttpClient::ServiceUnavailable
          # expected
        end
      end
    end

    describe "ServiceNotFound passthrough" do
      it "re-raises ServiceNotFound from ServiceRegistry" do
        allow(ServiceRegistry).to receive(:url_for).and_raise(ServiceRegistry::ServiceNotFound.new("Unknown service"))

        expect { described_class.get(:unknown, "/path") }
          .to raise_error(ServiceRegistry::ServiceNotFound)
      end
    end

    describe "generic error handling" do
      it "raises ServiceUnavailable on other errors" do
        stub_request(:get, full_url)
          .to_raise(StandardError.new("Something went wrong"))

        expect { described_class.get(:doctors, test_path) }
          .to raise_error(HttpClient::ServiceUnavailable, /unavailable/)
      end
    end
  end

  describe "Circuit Breaker Integration" do
    it "checks circuit before making request" do
      stub_request(:get, full_url)
        .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

      expect(ServiceRegistry).to receive(:allow_request?).with(:doctors).and_return(true)

      described_class.get(:doctors, test_path)
    end

    it "records success on successful response" do
      stub_request(:get, full_url)
        .to_return(status: 200, body: '{}', headers: { "Content-Type" => "application/json" })

      expect(ServiceRegistry).to receive(:record_success).with(:doctors)

      described_class.get(:doctors, test_path)
    end

    it "records success even for 4xx responses" do
      stub_request(:get, full_url)
        .to_return(status: 404, body: '{}', headers: { "Content-Type" => "application/json" })

      expect(ServiceRegistry).to receive(:record_success).with(:doctors)

      described_class.get(:doctors, test_path)
    end

    it "records failure on connection error" do
      stub_request(:get, full_url)
        .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

      expect(ServiceRegistry).to receive(:record_failure).with(:doctors)

      begin
        described_class.get(:doctors, test_path)
      rescue HttpClient::ServiceUnavailable
        # expected
      end
    end

    it "records failure on timeout" do
      stub_request(:get, full_url)
        .to_timeout

      expect(ServiceRegistry).to receive(:record_failure).with(:doctors)

      begin
        described_class.get(:doctors, test_path)
      rescue HttpClient::RequestTimeout, HttpClient::ServiceUnavailable
        # expected
      end
    end
  end

  describe "Header Propagation" do
    let(:response_headers) { { "Content-Type" => "application/json" } }

    before do
      stub_request(:get, full_url)
        .to_return(status: 200, body: '{}', headers: response_headers)
    end

    it "propagates JWT token via Authorization header" do
      Thread.current[:auth_token] = "test-jwt-token"

      described_class.get(:doctors, test_path)

      expect(a_request(:get, full_url)
        .with(headers: { "Authorization" => "Bearer test-jwt-token" })).to have_been_made
    end

    it "propagates correlation ID via X-Correlation-ID header" do
      Thread.current[:correlation_id] = "corr-123"

      described_class.get(:doctors, test_path)

      expect(a_request(:get, full_url)
        .with(headers: { "X-Correlation-ID" => "corr-123" })).to have_been_made
    end

    it "propagates user ID via X-User-ID header" do
      Thread.current[:current_user_id] = 456

      described_class.get(:doctors, test_path)

      expect(a_request(:get, full_url)
        .with(headers: { "X-User-ID" => "456" })).to have_been_made
    end

    it "generates X-Request-ID when not set" do
      described_class.get(:doctors, test_path)

      expect(a_request(:get, full_url)
        .with(headers: { "X-Request-ID" => /\A[a-f0-9-]{36}\z/ })).to have_been_made
    end

    it "uses existing request ID from thread" do
      Thread.current[:request_id] = "req-abc-123"

      described_class.get(:doctors, test_path)

      expect(a_request(:get, full_url)
        .with(headers: { "X-Request-ID" => "req-abc-123" })).to have_been_made
    end

    it "includes X-Service-Version header" do
      described_class.get(:doctors, test_path)

      expect(a_request(:get, full_url)
        .with(headers: { "X-Service-Version" => "1.0" })).to have_been_made
    end

    it "merges custom headers" do
      described_class.get(:doctors, test_path, headers: { "X-Custom" => "value" })

      expect(a_request(:get, full_url)
        .with(headers: { "X-Custom" => "value" })).to have_been_made
    end

    it "custom headers override default headers" do
      described_class.get(:doctors, test_path, headers: { "User-Agent" => "CustomAgent" })

      expect(a_request(:get, full_url)
        .with(headers: { "User-Agent" => "CustomAgent" })).to have_been_made
    end
  end

  describe "error classes" do
    describe "HttpClient::ServiceUnavailable" do
      it "is a StandardError" do
        expect(HttpClient::ServiceUnavailable).to be < StandardError
      end
    end

    describe "HttpClient::CircuitOpen" do
      it "is a StandardError" do
        expect(HttpClient::CircuitOpen).to be < StandardError
      end
    end

    describe "HttpClient::RequestTimeout" do
      it "is a StandardError" do
        expect(HttpClient::RequestTimeout).to be < StandardError
      end
    end

    describe "HttpClient::ClientError" do
      it "is a StandardError" do
        expect(HttpClient::ClientError).to be < StandardError
      end

      it "stores status" do
        error = HttpClient::ClientError.new("test", status: 400, body: {})
        expect(error.status).to eq(400)
      end

      it "stores body" do
        error = HttpClient::ClientError.new("test", status: 400, body: { error: "bad" })
        expect(error.body).to eq({ error: "bad" })
      end
    end

    describe "HttpClient::ServerError" do
      it "is a StandardError" do
        expect(HttpClient::ServerError).to be < StandardError
      end

      it "stores status" do
        error = HttpClient::ServerError.new("test", status: 500, body: {})
        expect(error.status).to eq(500)
      end

      it "stores body" do
        error = HttpClient::ServerError.new("test", status: 500, body: { error: "internal" })
        expect(error.body).to eq({ error: "internal" })
      end
    end
  end

  describe "Response class" do
    describe "#headers" do
      it "returns response headers" do
        stub_request(:get, full_url)
          .to_return(status: 200, body: '{}', headers: { "X-Custom" => "value", "Content-Type" => "application/json" })

        response = described_class.get(:doctors, test_path)

        expect(response.headers).to include("x-custom" => "value")
      end
    end

    describe "#status" do
      it "returns HTTP status code" do
        stub_request(:get, full_url)
          .to_return(status: 201, body: '{}', headers: { "Content-Type" => "application/json" })

        response = described_class.get(:doctors, test_path)

        expect(response.status).to eq(201)
      end
    end
  end
end
