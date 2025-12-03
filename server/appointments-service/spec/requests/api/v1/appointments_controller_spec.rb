# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Appointments", type: :request do
  let(:user_id) { SecureRandom.uuid }
  let(:doctor_id) { SecureRandom.uuid }
  let(:clinic_id) { SecureRandom.uuid }

  describe "GET /api/v1/appointments" do
    let!(:appointments) { create_list(:appointment, 3) }

    it "returns all appointments" do
      get "/api/v1/appointments"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointments"].size).to eq(3)
    end

    it "filters by user_id" do
      user_appointment = create(:appointment, user_id: user_id)
      get "/api/v1/appointments", params: { user_id: user_id }

      json = JSON.parse(response.body)
      expect(json["appointments"].size).to eq(1)
      expect(json["appointments"].first["user_id"]).to eq(user_id)
    end

    it "filters by doctor_id" do
      doctor_appointment = create(:appointment, doctor_id: doctor_id)
      get "/api/v1/appointments", params: { doctor_id: doctor_id }

      json = JSON.parse(response.body)
      expect(json["appointments"].size).to eq(1)
      expect(json["appointments"].first["doctor_id"]).to eq(doctor_id)
    end

    it "filters by status" do
      confirmed_appointment = create(:appointment, :confirmed)
      get "/api/v1/appointments", params: { status: "confirmed" }

      json = JSON.parse(response.body)
      expect(json["appointments"].all? { |a| a["status"] == "confirmed" }).to be true
    end

    it "includes pagination metadata" do
      get "/api/v1/appointments"

      json = JSON.parse(response.body)
      expect(json["meta"]).to include("current_page", "total_pages", "total_count")
    end
  end

  describe "GET /api/v1/appointments/:id" do
    let(:appointment) { create(:appointment) }

    it "returns appointment details" do
      get "/api/v1/appointments/#{appointment.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointment"]["id"]).to eq(appointment.id)
    end

    it "returns 404 when appointment not found" do
      get "/api/v1/appointments/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Appointment not found")
    end
  end

  describe "POST /api/v1/appointments" do
    let(:valid_params) do
      {
        appointment: {
          user_id: user_id,
          doctor_id: doctor_id,
          clinic_id: clinic_id,
          appointment_date: 1.week.from_now.to_date,
          start_time: "10:00",
          end_time: "10:30",
          consultation_type: "in_person",
          reason: "Regular checkup"
        }
      }
    end

    let(:doctor_data) do
      {
        "id" => doctor_id,
        "clinic_id" => clinic_id,
        "active" => true,
        "accepting_new_patients" => true,
        "consultation_fee" => 150.00
      }
    end

    before do
      allow(HttpClient).to receive(:get).with("http://localhost:3001/api/v1/users/#{user_id}").and_return({ "id" => user_id })
      allow(HttpClient).to receive(:get).with("http://localhost:3002/api/v1/doctors/#{doctor_id}").and_return(doctor_data)
    end

    it "creates a new appointment" do
      expect {
        post "/api/v1/appointments", params: valid_params
      }.to change(Appointment, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["appointment"]["user_id"]).to eq(user_id)
      expect(json["appointment"]["doctor_id"]).to eq(doctor_id)
    end

    it "returns error with invalid params" do
      invalid_params = valid_params.dup
      invalid_params[:appointment].delete(:user_id)

      post "/api/v1/appointments", params: invalid_params

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
    end
  end

  describe "PATCH /api/v1/appointments/:id" do
    let(:appointment) { create(:appointment) }

    it "updates appointment" do
      patch "/api/v1/appointments/#{appointment.id}",
            params: { appointment: { reason: "Updated reason" } }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointment"]["reason"]).to eq("Updated reason")
    end

    it "returns error with invalid data" do
      patch "/api/v1/appointments/#{appointment.id}",
            params: { appointment: { appointment_date: 1.day.ago.to_date } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/appointments/:id" do
    let(:appointment) { create(:appointment) }

    it "deletes appointment" do
      expect {
        delete "/api/v1/appointments/#{appointment.id}"
      }.to change(Appointment, :count).by(0) # Soft delete

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/appointments/:id/confirm" do
    let(:appointment) { create(:appointment, status: "pending") }

    it "confirms appointment" do
      post "/api/v1/appointments/#{appointment.id}/confirm"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointment"]["status"]).to eq("confirmed")
      expect(json["appointment"]["confirmed_at"]).to be_present
    end

    it "returns error when appointment cannot be confirmed" do
      completed_appointment = create(:appointment, :completed)
      post "/api/v1/appointments/#{completed_appointment.id}/confirm"

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/appointments/:id/cancel" do
    let(:appointment) { create(:appointment, :confirmed) }

    it "cancels appointment" do
      post "/api/v1/appointments/#{appointment.id}/cancel",
           params: { cancelled_by: "patient", reason: "Personal reasons" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointment"]["status"]).to eq("cancelled")
      expect(json["appointment"]["cancelled_by"]).to eq("patient")
    end

    it "returns warning when within 24-hour window" do
      near_appointment = create(:appointment,
                               :confirmed,
                               appointment_date: Date.current,
                               start_time: (Time.current + 20.hours).strftime("%H:%M:%S"),
                               end_time: (Time.current + 20.5.hours).strftime("%H:%M:%S"))

      post "/api/v1/appointments/#{near_appointment.id}/cancel",
           params: { cancelled_by: "patient" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["warning"]).to be_present
    end
  end

  describe "POST /api/v1/appointments/:id/complete" do
    let(:appointment) { create(:appointment, :in_progress) }

    it "completes appointment with notes" do
      post "/api/v1/appointments/#{appointment.id}/complete",
           params: { notes: "Patient is healthy", prescription: "Rest and fluids" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointment"]["status"]).to eq("completed")
      expect(json["appointment"]["notes"]).to eq("Patient is healthy")
      expect(json["appointment"]["prescription"]).to eq("Rest and fluids")
    end

    it "returns error when appointment cannot be completed" do
      pending_appointment = create(:appointment, status: "pending")
      post "/api/v1/appointments/#{pending_appointment.id}/complete"

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/appointments/upcoming" do
    let!(:upcoming_appointment) { create(:appointment, :upcoming_appointment, user_id: user_id) }
    let!(:past_appointment) { create(:appointment, :past_appointment, :completed, user_id: user_id) }

    it "returns upcoming appointments for user" do
      get "/api/v1/appointments/upcoming", params: { user_id: user_id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointments"].size).to eq(1)
      expect(json["appointments"].first["id"]).to eq(upcoming_appointment.id)
    end

    it "returns upcoming appointments for doctor" do
      doctor_appointment = create(:appointment, :upcoming_appointment, doctor_id: doctor_id)
      get "/api/v1/appointments/upcoming", params: { doctor_id: doctor_id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointments"].first["id"]).to eq(doctor_appointment.id)
    end

    it "returns error when neither user_id nor doctor_id provided" do
      get "/api/v1/appointments/upcoming"

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("user_id or doctor_id is required")
    end
  end

  describe "GET /api/v1/appointments/history" do
    let!(:past_appointment) { create(:appointment, :past_appointment, :completed, user_id: user_id) }
    let!(:upcoming_appointment) { create(:appointment, :upcoming_appointment, user_id: user_id) }

    it "returns appointment history for user" do
      get "/api/v1/appointments/history", params: { user_id: user_id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["appointments"].size).to eq(1)
      expect(json["appointments"].first["id"]).to eq(past_appointment.id)
    end

    it "includes pagination metadata" do
      get "/api/v1/appointments/history", params: { user_id: user_id }

      json = JSON.parse(response.body)
      expect(json["meta"]).to include("current_page", "total_pages")
    end

    it "returns error when neither user_id nor doctor_id provided" do
      get "/api/v1/appointments/history"

      expect(response).to have_http_status(:bad_request)
    end
  end
end
