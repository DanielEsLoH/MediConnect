# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::Internal::BaseController, type: :controller do
  # Create an anonymous test controller that inherits from BaseController
  controller(Api::Internal::BaseController) do
    def index
      render json: { message: "success" }
    end

    def show
      raise ActiveRecord::RecordNotFound, "User not found"
    end

    def create
      params.require(:name)
    end
  end

  before do
    routes.draw do
      get "index" => "api/internal/base#index"
      get "show" => "api/internal/base#show"
      post "create" => "api/internal/base#create"
    end
  end

  describe "verify_internal_request" do
    context "with valid X-Internal-Service header" do
      it "allows the request to proceed" do
        request.headers["X-Internal-Service"] = "api-gateway"

        get :index

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("success")
      end

      it "logs the request with service name" do
        request.headers["X-Internal-Service"] = "doctors-service"
        request.headers["X-Request-ID"] = "req-12345"

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Request from doctors-service/).at_least(:once)

        get :index
      end

      it "accepts any non-empty service name" do
        request.headers["X-Internal-Service"] = "custom-service"

        get :index

        expect(response).to have_http_status(:ok)
      end
    end

    context "without X-Internal-Service header" do
      it "returns 401 unauthorized" do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message" do
        get :index

        json = JSON.parse(response.body)
        expect(json["error"]).to include("internal service header required")
      end

      it "logs the rejection" do
        expect(Rails.logger).to receive(:warn).with(/Request rejected.*missing X-Internal-Service/)

        get :index
      end

      it "includes IP in rejection log" do
        expect(Rails.logger).to receive(:warn).with(/ip=/)

        get :index
      end

      it "includes path in rejection log" do
        expect(Rails.logger).to receive(:warn).with(/path=/)

        get :index
      end
    end

    context "with empty X-Internal-Service header" do
      it "returns 401 unauthorized" do
        request.headers["X-Internal-Service"] = ""

        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "set_request_context" do
    before do
      request.headers["X-Internal-Service"] = "test-service"
    end

    it "sets request_id in thread current" do
      request.headers["X-Request-ID"] = "req-abc-123"

      get :index

      expect(Thread.current[:request_id]).to eq("req-abc-123")
    end

    it "generates request_id if not provided" do
      get :index

      expect(Thread.current[:request_id]).to match(/\A[a-f0-9-]{36}\z/)
    end

    it "sets correlation_id in thread current" do
      request.headers["X-Correlation-ID"] = "corr-xyz-789"

      get :index

      expect(Thread.current[:correlation_id]).to eq("corr-xyz-789")
    end

    it "sets calling_service in thread current" do
      request.headers["X-Internal-Service"] = "payments-service"

      get :index

      expect(Thread.current[:calling_service]).to eq("payments-service")
    end
  end

  describe "error handlers" do
    before do
      request.headers["X-Internal-Service"] = "test-service"
    end

    describe "record_not_found" do
      it "returns 404 status" do
        get :show

        expect(response).to have_http_status(:not_found)
      end

      it "returns error JSON with message" do
        get :show

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Record not found")
      end

      it "includes exception details" do
        get :show

        json = JSON.parse(response.body)
        expect(json["details"]).to include("User not found")
      end

      it "logs the not found event" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Record not found/).at_least(:once)

        get :show
      end
    end

    describe "parameter_missing" do
      it "returns 400 status" do
        post :create, params: {}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns error JSON with message" do
        post :create, params: {}

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Parameter missing")
      end

      it "includes exception details" do
        post :create, params: {}

        json = JSON.parse(response.body)
        expect(json["details"]).to be_present
      end

      it "logs the missing parameter" do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)
        expect(Rails.logger).to receive(:warn).with(/Parameter missing/).at_least(:once)

        post :create, params: {}
      end
    end
  end
end
