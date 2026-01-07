# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Internal::AppointmentsController", type: :request do
  let(:internal_headers) do
    {
      "X-Internal-Service" => "payments-service",
      "X-Request-ID" => SecureRandom.uuid,
      "Content-Type" => "application/json"
    }
  end

  let(:user_id) { SecureRandom.uuid }
  let(:doctor_id) { SecureRandom.uuid }
  let(:clinic_id) { SecureRandom.uuid }

  describe "authentication" do
    let!(:appointment) { create(:appointment) }

    context "without X-Internal-Service header" do
      it "returns 401 unauthorized" do
        get "/internal/appointments/#{appointment.id}"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to include("internal service header required")
      end
    end

    context "with empty X-Internal-Service header" do
      it "returns 401 unauthorized" do
        get "/internal/appointments/#{appointment.id}",
          headers: { "X-Internal-Service" => "" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with valid X-Internal-Service header" do
      it "allows the request" do
        get "/internal/appointments/#{appointment.id}",
          headers: internal_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /internal/appointments/:id" do
    context "when appointment exists" do
      let!(:appointment) do
        create(:appointment, :confirmed,
          user_id: user_id,
          doctor_id: doctor_id,
          clinic_id: clinic_id,
          consultation_fee: 150.00,
          notes: "Test notes"
        )
      end

      it "returns the appointment data" do
        get "/internal/appointments/#{appointment.id}",
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointment"]["id"]).to eq(appointment.id)
        expect(json["appointment"]["user_id"]).to eq(user_id)
        expect(json["appointment"]["doctor_id"]).to eq(doctor_id)
        expect(json["appointment"]["status"]).to eq("confirmed")
      end

      it "includes all required fields" do
        get "/internal/appointments/#{appointment.id}",
          headers: internal_headers

        json = JSON.parse(response.body)
        appointment_data = json["appointment"]

        expect(appointment_data).to have_key("id")
        expect(appointment_data).to have_key("user_id")
        expect(appointment_data).to have_key("doctor_id")
        expect(appointment_data).to have_key("clinic_id")
        expect(appointment_data).to have_key("appointment_date")
        expect(appointment_data).to have_key("start_time")
        expect(appointment_data).to have_key("end_time")
        expect(appointment_data).to have_key("scheduled_datetime")
        expect(appointment_data).to have_key("end_datetime")
        expect(appointment_data).to have_key("duration_minutes")
        expect(appointment_data).to have_key("consultation_type")
        expect(appointment_data).to have_key("status")
        expect(appointment_data).to have_key("consultation_fee")
        expect(appointment_data).to have_key("notes")
        expect(appointment_data).to have_key("prescription")
        expect(appointment_data).to have_key("cancellation_reason")
        expect(appointment_data).to have_key("cancelled_by")
        expect(appointment_data).to have_key("cancelled_at")
        expect(appointment_data).to have_key("confirmed_at")
        expect(appointment_data).to have_key("completed_at")
        expect(appointment_data).to have_key("created_at")
        expect(appointment_data).to have_key("updated_at")
      end
    end

    context "when appointment does not exist" do
      it "returns 404 not found" do
        get "/internal/appointments/#{SecureRandom.uuid}",
          headers: internal_headers

        expect(response).to have_http_status(:not_found)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Record not found")
      end
    end
  end

  describe "POST /internal/appointments/batch" do
    let!(:appointments) do
      create_list(:appointment, 3, user_id: user_id)
    end

    context "with valid appointment_ids" do
      it "returns appointments for the given IDs" do
        post "/internal/appointments/batch",
          params: { appointment_ids: appointments.map(&:id) }.to_json,
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"].length).to eq(3)
        expect(json["meta"]["requested"]).to eq(3)
        expect(json["meta"]["found"]).to eq(3)
      end
    end

    context "with some non-existent IDs" do
      it "returns only found appointments" do
        ids = appointments.take(2).map(&:id) + [ SecureRandom.uuid ]

        post "/internal/appointments/batch",
          params: { appointment_ids: ids }.to_json,
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"].length).to eq(2)
        expect(json["meta"]["requested"]).to eq(3)
        expect(json["meta"]["found"]).to eq(2)
      end
    end

    context "with empty array" do
      it "returns empty appointments" do
        post "/internal/appointments/batch",
          params: { appointment_ids: [] }.to_json,
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"]).to be_empty
        expect(json["meta"]["requested"]).to eq(0)
        expect(json["meta"]["found"]).to eq(0)
      end
    end

    context "with too many IDs" do
      it "returns 400 bad request" do
        ids = 101.times.map { SecureRandom.uuid }

        post "/internal/appointments/batch",
          params: { appointment_ids: ids }.to_json,
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json["error"]).to include("max 100 items")
      end
    end

    context "with missing appointment_ids" do
      it "returns 400 bad request" do
        post "/internal/appointments/batch",
          params: {}.to_json,
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with non-array appointment_ids" do
      it "returns 400 bad request" do
        post "/internal/appointments/batch",
          params: { appointment_ids: "not-an-array" }.to_json,
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "GET /internal/appointments/by_user/:user_id" do
    let!(:user_appointments) do
      [
        create(:appointment, user_id: user_id, status: "pending"),
        create(:appointment, :confirmed, user_id: user_id),
        create(:appointment, :completed, user_id: user_id)
      ]
    end

    let!(:other_user_appointment) { create(:appointment) }

    it "returns appointments for the specified user" do
      get "/internal/appointments/by_user/#{user_id}",
        headers: internal_headers

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["appointments"].length).to eq(3)
      expect(json["meta"]["count"]).to eq(3)
    end

    context "with status filter" do
      it "filters appointments by status" do
        get "/internal/appointments/by_user/#{user_id}",
          params: { status: "confirmed" },
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"].length).to eq(1)
        expect(json["appointments"].first["status"]).to eq("confirmed")
      end
    end

    context "with from_date filter" do
      let!(:past_appointment) do
        # Create past appointment (need to skip validation)
        apt = build(:appointment, user_id: user_id, appointment_date: 7.days.ago.to_date)
        apt.save(validate: false)
        apt
      end

      it "filters appointments from the specified date" do
        get "/internal/appointments/by_user/#{user_id}",
          params: { from_date: Date.current.to_s },
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        # Should only return future appointments
        json["appointments"].each do |apt|
          expect(Date.parse(apt["appointment_date"])).to be >= Date.current
        end
      end
    end

    context "with limit parameter" do
      before do
        create_list(:appointment, 10, user_id: user_id)
      end

      it "limits the number of appointments returned" do
        get "/internal/appointments/by_user/#{user_id}",
          params: { limit: 5 },
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"].length).to eq(5)
      end
    end

    context "when user has no appointments" do
      it "returns empty array" do
        get "/internal/appointments/by_user/#{SecureRandom.uuid}",
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"]).to be_empty
        expect(json["meta"]["count"]).to eq(0)
      end
    end
  end

  describe "GET /internal/appointments/by_doctor/:doctor_id" do
    let!(:doctor_appointments) do
      [
        create(:appointment, doctor_id: doctor_id, status: "pending"),
        create(:appointment, :confirmed, doctor_id: doctor_id)
      ]
    end

    let!(:other_doctor_appointment) { create(:appointment) }

    it "returns appointments for the specified doctor" do
      get "/internal/appointments/by_doctor/#{doctor_id}",
        headers: internal_headers

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["appointments"].length).to eq(2)
      expect(json["meta"]["count"]).to eq(2)
    end

    context "with status filter" do
      it "filters appointments by status" do
        get "/internal/appointments/by_doctor/#{doctor_id}",
          params: { status: "confirmed" },
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"].length).to eq(1)
        expect(json["appointments"].first["status"]).to eq("confirmed")
      end
    end

    context "with date filter" do
      let(:target_date) { 7.days.from_now.to_date }

      let!(:dated_appointment) do
        create(:appointment, doctor_id: doctor_id, appointment_date: target_date)
      end

      it "filters appointments by date" do
        get "/internal/appointments/by_doctor/#{doctor_id}",
          params: { date: target_date.to_s },
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        json["appointments"].each do |apt|
          expect(apt["appointment_date"]).to eq(target_date.to_s)
        end
      end
    end

    context "with limit parameter" do
      before do
        create_list(:appointment, 10, doctor_id: doctor_id)
      end

      it "limits the number of appointments returned" do
        get "/internal/appointments/by_doctor/#{doctor_id}",
          params: { limit: 3 },
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointments"].length).to eq(3)
      end
    end
  end

  describe "GET /internal/appointments/:id/exists" do
    context "when appointment exists" do
      let!(:appointment) do
        create(:appointment, :confirmed, user_id: user_id, doctor_id: doctor_id)
      end

      it "returns exists: true with details" do
        get "/internal/appointments/#{appointment.id}/exists",
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["exists"]).to be true
        expect(json["status"]).to eq("confirmed")
        expect(json["user_id"]).to eq(user_id)
        expect(json["doctor_id"]).to eq(doctor_id)
      end
    end

    context "when appointment does not exist" do
      it "returns exists: false" do
        get "/internal/appointments/#{SecureRandom.uuid}/exists",
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["exists"]).to be false
        expect(json["status"]).to be_nil
        expect(json["user_id"]).to be_nil
        expect(json["doctor_id"]).to be_nil
      end
    end
  end

  describe "GET /internal/appointments/:id/payment_info" do
    context "when appointment exists" do
      let!(:appointment) do
        create(:appointment, :confirmed,
          user_id: user_id,
          doctor_id: doctor_id,
          clinic_id: clinic_id,
          consultation_fee: 200.00,
          notes: "Test payment notes"
        )
      end

      it "returns payment-related appointment data" do
        get "/internal/appointments/#{appointment.id}/payment_info",
          headers: internal_headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json["appointment_id"]).to eq(appointment.id)
        expect(json["user_id"]).to eq(user_id)
        expect(json["doctor_id"]).to eq(doctor_id)
        expect(json["clinic_id"]).to eq(clinic_id)
        expect(json["consultation_fee"]).to eq("200.0")
        expect(json["currency"]).to eq("USD")
        expect(json["status"]).to eq("confirmed")
        expect(json["consultation_type"]).to eq("in_person")
        expect(json["notes"]).to eq("Test payment notes")
      end

      it "includes schedule information" do
        get "/internal/appointments/#{appointment.id}/payment_info",
          headers: internal_headers

        json = JSON.parse(response.body)
        expect(json).to have_key("appointment_date")
        expect(json).to have_key("start_time")
        expect(json).to have_key("end_time")
        expect(json).to have_key("scheduled_datetime")
        expect(json).to have_key("duration_minutes")
      end
    end

    context "when appointment does not exist" do
      it "returns 404 not found" do
        get "/internal/appointments/#{SecureRandom.uuid}/payment_info",
          headers: internal_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
