# frozen_string_literal: true

require "rails_helper"

RSpec.describe HttpClient do
  describe HttpClient::Response do
    describe "#success?" do
      it "returns true for 2xx status codes" do
        response = described_class.new(status: 200, body: {}, headers: {})
        expect(response.success?).to be true
      end

      it "returns false for non-2xx status codes" do
        response = described_class.new(status: 404, body: {}, headers: {})
        expect(response.success?).to be false
      end
    end

    describe "#redirect?" do
      it "returns true for 3xx status codes" do
        response = described_class.new(status: 301, body: {}, headers: {})
        expect(response.redirect?).to be true
      end
    end

    describe "#client_error?" do
      it "returns true for 4xx status codes" do
        response = described_class.new(status: 400, body: {}, headers: {})
        expect(response.client_error?).to be true
      end
    end

    describe "#server_error?" do
      it "returns true for 5xx status codes" do
        response = described_class.new(status: 500, body: {}, headers: {})
        expect(response.server_error?).to be true
      end
    end

    describe "#not_found?" do
      it "returns true for 404" do
        response = described_class.new(status: 404, body: {}, headers: {})
        expect(response.not_found?).to be true
      end
    end

    describe "#unauthorized?" do
      it "returns true for 401" do
        response = described_class.new(status: 401, body: {}, headers: {})
        expect(response.unauthorized?).to be true
      end
    end

    describe "#forbidden?" do
      it "returns true for 403" do
        response = described_class.new(status: 403, body: {}, headers: {})
        expect(response.forbidden?).to be true
      end
    end

    describe "#unprocessable?" do
      it "returns true for 422" do
        response = described_class.new(status: 422, body: {}, headers: {})
        expect(response.unprocessable?).to be true
      end
    end

    describe "#dig" do
      it "extracts nested values from body" do
        response = described_class.new(
          status: 200,
          body: { "user" => { "email" => "test@example.com" } },
          headers: {}
        )
        expect(response.dig("user", "email")).to eq("test@example.com")
      end

      it "returns body if path is empty" do
        body = { "key" => "value" }
        response = described_class.new(status: 200, body: body, headers: {})
        expect(response.dig).to eq(body)
      end

      it "returns nil if body is not a hash" do
        response = described_class.new(status: 200, body: "string", headers: {})
        expect(response.dig("key")).to be_nil
      end
    end
  end

  describe "class methods" do
    it "responds to .get" do
      expect(described_class).to respond_to(:get)
    end

    it "responds to .post" do
      expect(described_class).to respond_to(:post)
    end

    it "responds to .put" do
      expect(described_class).to respond_to(:put)
    end

    it "responds to .patch" do
      expect(described_class).to respond_to(:patch)
    end

    it "responds to .delete" do
      expect(described_class).to respond_to(:delete)
    end
  end

  describe HttpClient::ClientError do
    it "stores status and body" do
      error = described_class.new("Bad request", status: 400, body: { error: "invalid" })

      expect(error.message).to eq("Bad request")
      expect(error.status).to eq(400)
      expect(error.body).to eq({ error: "invalid" })
    end
  end

  describe HttpClient::ServerError do
    it "stores status and body" do
      error = described_class.new("Server error", status: 500, body: { error: "internal" })

      expect(error.message).to eq("Server error")
      expect(error.status).to eq(500)
      expect(error.body).to eq({ error: "internal" })
    end
  end

  describe HttpClient::CircuitOpen do
    it "is a StandardError" do
      expect(described_class.new("Circuit open")).to be_a(StandardError)
    end
  end

  describe HttpClient::RequestTimeout do
    it "is a StandardError" do
      expect(described_class.new("Timeout")).to be_a(StandardError)
    end
  end

  describe HttpClient::ServiceUnavailable do
    it "is a StandardError" do
      expect(described_class.new("Unavailable")).to be_a(StandardError)
    end
  end
end
