# frozen_string_literal: true

require "rails_helper"

RSpec.describe HttpClient do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("HTTP_CLIENT_TIMEOUT", anything).and_return(10)
    allow(ENV).to receive(:fetch).with("HTTP_CLIENT_OPEN_TIMEOUT", anything).and_return(5)
    allow(ENV).to receive(:fetch).with("HTTP_CLIENT_MAX_RETRIES", anything).and_return(3)

    # Reset circuit breaker state
    ServiceRegistry.reset_all_circuits
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
    end

    context "with query parameters" do
      before do
        stub_request(:get, "#{base_url}/api/users")
          .with(query: { page: 1, per_page: 10 })
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
        expect(response.status).to eq(404)
      end
    end

    context "with 500 response" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_return(
            status: 500,
            body: { error: "Internal error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns server error response" do
        response = described_class.get(:users, "/api/users/1")

        expect(response).to be_server_error
        expect(response.status).to eq(500)
      end
    end

    context "with timeout" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_timeout
      end

      it "raises ServiceUnavailable error wrapping the timeout" do
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(HttpClient::ServiceUnavailable)
      end
    end

    context "when service is unavailable" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises ServiceUnavailable error" do
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(HttpClient::ServiceUnavailable)
      end
    end

    context "with unknown service" do
      it "raises ServiceNotFound error" do
        expect { described_class.get(:unknown_service, "/api/test") }
          .to raise_error(ServiceRegistry::ServiceNotFound)
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

      it "returns ok status" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("ok")
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
    end

    context "when service returns error" do
      before do
        stub_request(:get, "#{base_url}/health")
          .to_return(
            status: 503,
            body: { status: "error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns error status" do
        result = described_class.health_check(:users)

        expect(result[:status]).to eq("error")
        expect(result[:http_status]).to eq(503)
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

  describe "circuit breaker integration" do
    let(:base_url) { ServiceRegistry.url_for(:users) }

    context "when circuit is open" do
      before do
        # Simulate circuit being opened
        allow(ServiceRegistry).to receive(:allow_request?).with(:users).and_return(false)
      end

      it "raises ServiceUnavailable error with circuit breaker message" do
        # NOTE: CircuitOpen is raised but gets caught and re-raised as ServiceUnavailable
        # This is the actual behavior - the test documents it
        expect { described_class.get(:users, "/api/users/1") }
          .to raise_error(HttpClient::ServiceUnavailable, /Circuit breaker is open/)
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

      it "records success with circuit breaker" do
        expect(ServiceRegistry).to receive(:record_success).with(:users)

        described_class.get(:users, "/api/users/1")
      end
    end

    context "on failed request" do
      before do
        stub_request(:get, "#{base_url}/api/users/1")
          .to_timeout
      end

      it "records failure with circuit breaker" do
        expect(ServiceRegistry).to receive(:record_failure).with(:users)

        expect { described_class.get(:users, "/api/users/1") }.to raise_error(HttpClient::ServiceUnavailable)
      end
    end
  end

  describe "Response class" do
    describe "#success?" do
      it "returns true for 2xx status" do
        response = HttpClient::Response.new(status: 200, body: {}, headers: {})
        expect(response).to be_success
      end

      it "returns false for non-2xx status" do
        response = HttpClient::Response.new(status: 404, body: {}, headers: {})
        expect(response).not_to be_success
      end
    end

    describe "#redirect?" do
      it "returns true for 3xx status" do
        response = HttpClient::Response.new(status: 301, body: {}, headers: {})
        expect(response).to be_redirect
      end

      it "returns false for non-3xx status" do
        response = HttpClient::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_redirect
      end
    end

    describe "#client_error?" do
      it "returns true for 4xx status" do
        response = HttpClient::Response.new(status: 404, body: {}, headers: {})
        expect(response).to be_client_error
      end

      it "returns false for non-4xx status" do
        response = HttpClient::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_client_error
      end
    end

    describe "#server_error?" do
      it "returns true for 5xx status" do
        response = HttpClient::Response.new(status: 500, body: {}, headers: {})
        expect(response).to be_server_error
      end

      it "returns false for non-5xx status" do
        response = HttpClient::Response.new(status: 200, body: {}, headers: {})
        expect(response).not_to be_server_error
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
        .with(headers: { "User-Agent" => "MediConnect-API-Gateway/1.0" })).to have_been_made
    end

    it "includes X-Internal-Service header" do
      described_class.get(:users, "/api/test")

      expect(a_request(:get, "#{base_url}/api/test")
        .with(headers: { "X-Internal-Service" => "api-gateway" })).to have_been_made
    end
  end
end
