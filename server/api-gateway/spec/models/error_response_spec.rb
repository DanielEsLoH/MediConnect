# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorResponse do
  describe ".build" do
    it "builds error response with all fields" do
      response = described_class.build(
        status: :not_found,
        error: "user_not_found",
        message: "User not found"
      )

      expect(response[:status]).to eq(404)
      expect(response[:error]).to eq("user_not_found")
      expect(response[:message]).to eq("User not found")
      expect(response[:timestamp]).to be_present
    end

    it "converts symbol status to integer" do
      response = described_class.build(
        status: :unauthorized,
        error: "auth_error",
        message: "Not authorized"
      )

      expect(response[:status]).to eq(401)
    end

    it "accepts integer status directly" do
      response = described_class.build(
        status: 422,
        error: "validation_error",
        message: "Invalid data"
      )

      expect(response[:status]).to eq(422)
    end

    it "includes request_id when provided" do
      response = described_class.build(
        status: :bad_request,
        error: "bad_request",
        message: "Bad request",
        request_id: "req-123"
      )

      expect(response[:request_id]).to eq("req-123")
    end

    it "includes details when provided" do
      details = [ "Field1 is required", "Field2 is invalid" ]
      response = described_class.build(
        status: :unprocessable_entity,
        error: "validation_failed",
        message: "Validation failed",
        details: details
      )

      expect(response[:details]).to eq(details)
    end

    it "omits details when nil" do
      response = described_class.build(
        status: :bad_request,
        error: "bad_request",
        message: "Bad request"
      )

      expect(response).not_to have_key(:details)
    end

    it "defaults unknown status to 500" do
      response = described_class.build(
        status: :unknown_status,
        error: "error",
        message: "Error"
      )

      expect(response[:status]).to eq(500)
    end
  end

  describe ".bad_request" do
    it "builds bad request response" do
      response = described_class.bad_request("Invalid input")

      expect(response[:status]).to eq(400)
      expect(response[:error]).to eq("bad_request")
      expect(response[:message]).to eq("Invalid input")
    end

    it "includes details when provided" do
      response = described_class.bad_request("Invalid input", details: [ "Field is required" ])

      expect(response[:details]).to eq([ "Field is required" ])
    end
  end

  describe ".unauthorized" do
    it "builds unauthorized response" do
      response = described_class.unauthorized("Token expired")

      expect(response[:status]).to eq(401)
      expect(response[:error]).to eq("unauthorized")
      expect(response[:message]).to eq("Token expired")
    end

    it "uses default message when not provided" do
      response = described_class.unauthorized

      expect(response[:message]).to eq("Unauthorized")
    end
  end

  describe ".forbidden" do
    it "builds forbidden response" do
      response = described_class.forbidden("Access denied")

      expect(response[:status]).to eq(403)
      expect(response[:error]).to eq("forbidden")
      expect(response[:message]).to eq("Access denied")
    end

    it "uses default message when not provided" do
      response = described_class.forbidden

      expect(response[:message]).to eq("Forbidden")
    end
  end

  describe ".not_found" do
    it "builds not found response" do
      response = described_class.not_found("User not found")

      expect(response[:status]).to eq(404)
      expect(response[:error]).to eq("not_found")
      expect(response[:message]).to eq("User not found")
    end

    it "uses default message when not provided" do
      response = described_class.not_found

      expect(response[:message]).to eq("Resource not found")
    end
  end

  describe ".conflict" do
    it "builds conflict response" do
      response = described_class.conflict("Resource already exists")

      expect(response[:status]).to eq(409)
      expect(response[:error]).to eq("conflict")
      expect(response[:message]).to eq("Resource already exists")
    end
  end

  describe ".unprocessable_entity" do
    it "builds unprocessable entity response" do
      response = described_class.unprocessable_entity("Validation failed")

      expect(response[:status]).to eq(422)
      expect(response[:error]).to eq("unprocessable_entity")
      expect(response[:message]).to eq("Validation failed")
    end

    it "includes validation details" do
      errors = [ "Email is invalid", "Name is required" ]
      response = described_class.unprocessable_entity("Validation failed", details: errors)

      expect(response[:details]).to eq(errors)
    end
  end

  describe ".too_many_requests" do
    it "builds too many requests response" do
      response = described_class.too_many_requests

      expect(response[:status]).to eq(429)
      expect(response[:error]).to eq("too_many_requests")
      expect(response[:message]).to eq("Rate limit exceeded")
    end

    it "includes retry_after when provided" do
      response = described_class.too_many_requests("Rate limit exceeded", retry_after: 60)

      expect(response[:retry_after]).to eq(60)
    end
  end

  describe ".internal_server_error" do
    it "builds internal server error response" do
      response = described_class.internal_server_error("Something went wrong")

      expect(response[:status]).to eq(500)
      expect(response[:error]).to eq("internal_server_error")
      expect(response[:message]).to eq("Something went wrong")
    end

    it "uses default message when not provided" do
      response = described_class.internal_server_error

      expect(response[:message]).to eq("Internal server error")
    end
  end

  describe ".service_unavailable" do
    it "builds service unavailable response" do
      response = described_class.service_unavailable("Service is down")

      expect(response[:status]).to eq(503)
      expect(response[:error]).to eq("service_unavailable")
      expect(response[:message]).to eq("Service is down")
    end

    it "uses default message when not provided" do
      response = described_class.service_unavailable

      expect(response[:message]).to eq("Service temporarily unavailable")
    end
  end

  describe ".gateway_timeout" do
    it "builds gateway timeout response" do
      response = described_class.gateway_timeout("Request timed out")

      expect(response[:status]).to eq(504)
      expect(response[:error]).to eq("gateway_timeout")
      expect(response[:message]).to eq("Request timed out")
    end

    it "uses default message when not provided" do
      response = described_class.gateway_timeout

      expect(response[:message]).to eq("Gateway timeout")
    end
  end

  describe ".from_exception" do
    it "handles ActiveRecord::RecordNotFound" do
      exception = ActiveRecord::RecordNotFound.new("Not found", "User")
      response = described_class.from_exception(exception)

      expect(response[:status]).to eq(404)
      expect(response[:error]).to eq("not_found")
    end

    it "handles ActiveRecord::RecordInvalid" do
      errors_mock = double("Errors", full_messages: [ "Email is invalid" ])
      record_mock = double("Record", errors: errors_mock)
      # Create the exception without passing a record, then stub the record method
      exception = ActiveRecord::RecordInvalid.allocate
      allow(exception).to receive(:record).and_return(record_mock)
      allow(exception).to receive(:message).and_return("Validation failed")
      response = described_class.from_exception(exception)

      expect(response[:status]).to eq(422)
      expect(response[:error]).to eq("unprocessable_entity")
      expect(response[:details]).to eq([ "Email is invalid" ])
    end

    it "handles ActionController::ParameterMissing" do
      exception = ActionController::ParameterMissing.new(:user)
      response = described_class.from_exception(exception)

      expect(response[:status]).to eq(400)
      expect(response[:error]).to eq("bad_request")
      expect(response[:message]).to include("user")
    end

    it "defaults to internal server error for unknown exceptions" do
      exception = StandardError.new("Unknown error")
      response = described_class.from_exception(exception)

      expect(response[:status]).to eq(500)
      expect(response[:error]).to eq("internal_server_error")
    end
  end

  describe "STATUS_CODES constant" do
    it "maps common HTTP statuses" do
      expect(ErrorResponse::STATUS_CODES[:bad_request]).to eq(400)
      expect(ErrorResponse::STATUS_CODES[:unauthorized]).to eq(401)
      expect(ErrorResponse::STATUS_CODES[:forbidden]).to eq(403)
      expect(ErrorResponse::STATUS_CODES[:not_found]).to eq(404)
      expect(ErrorResponse::STATUS_CODES[:unprocessable_entity]).to eq(422)
      expect(ErrorResponse::STATUS_CODES[:internal_server_error]).to eq(500)
      expect(ErrorResponse::STATUS_CODES[:service_unavailable]).to eq(503)
    end
  end
end
