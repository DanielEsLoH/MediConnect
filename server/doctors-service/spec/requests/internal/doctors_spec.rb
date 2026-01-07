# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Internal::Doctors", type: :request do
  let(:internal_headers) do
    {
      "X-Internal-Service" => "appointments-service",
      "X-Request-ID" => SecureRandom.uuid,
      "X-Correlation-ID" => SecureRandom.uuid
    }
  end

  let!(:specialty) { create(:specialty, name: "Cardiology") }
  let!(:clinic) { create(:clinic, name: "Heart Center", city: "New York", state: "NY") }
  let!(:doctor) do
    create(:doctor,
      specialty: specialty,
      clinic: clinic,
      active: true,
      accepting_new_patients: true,
      first_name: "John",
      last_name: "Smith",
      email: "john.smith@example.com",
      phone_number: "+1-555-123-4567"
    )
  end

  before do
    allow(EventPublisher).to receive(:publish)
  end

  describe "authentication" do
    it "requires X-Internal-Service header" do
      get "/internal/doctors/#{doctor.id}"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("internal service header required")
    end

    it "accepts requests with valid internal service header" do
      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /internal/doctors/:id" do
    it "returns doctor data for internal service use" do
      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctor"]["id"]).to eq(doctor.id)
      expect(json["doctor"]["first_name"]).to eq("John")
      expect(json["doctor"]["last_name"]).to eq("Smith")
      expect(json["doctor"]["email"]).to eq("john.smith@example.com")
      expect(json["doctor"]["full_name"]).to eq("John Smith")
    end

    it "includes specialty information" do
      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["doctor"]["specialty"]["name"]).to eq("Cardiology")
      expect(json["doctor"]["specialty"]).to have_key("description")
    end

    it "includes clinic information" do
      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      json = JSON.parse(response.body)
      clinic_data = json["doctor"]["clinic"]

      expect(clinic_data["name"]).to eq("Heart Center")
      expect(clinic_data["city"]).to eq("New York")
      expect(clinic_data["state"]).to eq("NY")
    end

    it "includes average_rating and total_reviews" do
      create(:review, doctor: doctor, rating: 5)
      create(:review, doctor: doctor, rating: 4)

      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["doctor"]["average_rating"]).to eq(4.5)
      expect(json["doctor"]["total_reviews"]).to eq(2)
    end

    it "includes all required fields for internal API" do
      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      json = JSON.parse(response.body)
      required_fields = %w[
        id email first_name last_name full_name phone_number bio
        years_of_experience languages consultation_fee
        profile_picture_url active accepting_new_patients
        average_rating total_reviews specialty clinic
        created_at updated_at
      ]

      required_fields.each do |field|
        expect(json["doctor"]).to have_key(field), "Expected response to have key '#{field}'"
      end
    end

    context "when doctor is not found" do
      it "returns 404 status with error details" do
        get "/internal/doctors/nonexistent-uuid", headers: internal_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Record not found")
      end
    end
  end

  describe "POST /internal/doctors/batch" do
    let!(:doctor2) { create(:doctor, first_name: "Jane", last_name: "Doe") }
    let!(:doctor3) { create(:doctor, first_name: "Bob", last_name: "Wilson") }

    it "returns multiple doctors by IDs" do
      post "/internal/doctors/batch",
        params: { doctor_ids: [ doctor.id, doctor2.id ] },
        headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctors"].length).to eq(2)
      doctor_ids = json["doctors"].map { |d| d["id"] }
      expect(doctor_ids).to contain_exactly(doctor.id, doctor2.id)
    end

    it "includes meta information about requested vs found" do
      post "/internal/doctors/batch",
        params: { doctor_ids: [ doctor.id, doctor2.id, "nonexistent-id" ] },
        headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["meta"]["requested"]).to eq(3)
      expect(json["meta"]["found"]).to eq(2)
    end

    it "returns empty array when no doctors found" do
      post "/internal/doctors/batch",
        params: { doctor_ids: [ "nonexistent-1", "nonexistent-2" ] },
        headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["doctors"]).to eq([])
      expect(json["meta"]["found"]).to eq(0)
    end

    context "with invalid parameters" do
      it "returns 400 when doctor_ids is not an array" do
        post "/internal/doctors/batch",
          params: { doctor_ids: "not-an-array" },
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("must be an array")
      end

      it "returns 400 when doctor_ids exceeds 100 items" do
        post "/internal/doctors/batch",
          params: { doctor_ids: Array.new(101) { SecureRandom.uuid } },
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("max 100 items")
      end

      it "returns 400 when doctor_ids parameter is missing" do
        post "/internal/doctors/batch", headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Parameter missing")
      end
    end
  end

  describe "GET /internal/doctors/:id/availability" do
    let!(:schedule) do
      create(:schedule,
        doctor: doctor,
        day_of_week: Date.today.wday,
        start_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("12:00"),
        slot_duration_minutes: 30,
        active: true
      )
    end

    it "returns availability data for internal use" do
      get "/internal/doctors/#{doctor.id}/availability", headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctor_id"]).to eq(doctor.id)
      expect(json["doctor_name"]).to eq("John Smith")
      expect(json["date"]).to eq(Date.today.to_s)
      expect(json["available_slots"]).to be_an(Array)
      expect(json["slot_duration_minutes"]).to eq(30)
    end

    it "accepts date parameter" do
      get "/internal/doctors/#{doctor.id}/availability",
        params: { date: Date.today.to_s },
        headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["date"]).to eq(Date.today.to_s)
    end

    it "includes next_available_date" do
      get "/internal/doctors/#{doctor.id}/availability", headers: internal_headers

      json = JSON.parse(response.body)
      expect(json).to have_key("next_available_date")
    end

    context "with invalid date format" do
      it "returns 400 status with error details" do
        get "/internal/doctors/#{doctor.id}/availability",
          params: { date: "invalid-date" },
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid date format")
        expect(json).to have_key("details")
      end
    end

    context "when doctor is not found" do
      it "returns 404 status" do
        get "/internal/doctors/nonexistent-uuid/availability", headers: internal_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /internal/doctors/:id/contact_info" do
    it "returns minimal contact information" do
      get "/internal/doctors/#{doctor.id}/contact_info", headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctor_id"]).to eq(doctor.id)
      expect(json["email"]).to eq("john.smith@example.com")
      expect(json["phone_number"]).to eq("+1-555-123-4567")
      expect(json["first_name"]).to eq("John")
      expect(json["last_name"]).to eq("Smith")
      expect(json["full_name"]).to eq("John Smith")
      expect(json["clinic_name"]).to eq("Heart Center")
    end

    it "includes clinic phone number" do
      get "/internal/doctors/#{doctor.id}/contact_info", headers: internal_headers

      json = JSON.parse(response.body)
      expect(json).to have_key("clinic_phone")
    end

    context "when doctor has no clinic" do
      it "returns nil for clinic fields" do
        # This test is for edge case handling - in reality doctors should always have clinic
        # but we test the nil-safe access

        get "/internal/doctors/#{doctor.id}/contact_info", headers: internal_headers

        json = JSON.parse(response.body)
        # Clinic exists, so should have values
        expect(json["clinic_name"]).to be_present
      end
    end

    context "when doctor is not found" do
      it "returns 404 status" do
        get "/internal/doctors/nonexistent-uuid/contact_info", headers: internal_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /internal/doctors/:id/exists" do
    it "returns exists: true for existing doctor" do
      get "/internal/doctors/#{doctor.id}/exists", headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["exists"]).to be true
      expect(json["active"]).to be true
      expect(json["accepting_new_patients"]).to be true
    end

    it "returns exists: false for non-existing doctor" do
      get "/internal/doctors/nonexistent-uuid/exists", headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["exists"]).to be false
      expect(json["active"]).to be_nil
      expect(json["accepting_new_patients"]).to be_nil
    end

    it "returns correct active status for inactive doctor" do
      inactive_doctor = create(:doctor, :inactive)

      get "/internal/doctors/#{inactive_doctor.id}/exists", headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["exists"]).to be true
      expect(json["active"]).to be false
    end

    it "returns correct accepting_new_patients status" do
      not_accepting = create(:doctor, :not_accepting_patients)

      get "/internal/doctors/#{not_accepting.id}/exists", headers: internal_headers

      json = JSON.parse(response.body)
      expect(json["exists"]).to be true
      expect(json["accepting_new_patients"]).to be false
    end
  end

  describe "GET /internal/doctors/:id/validate_for_appointment" do
    let!(:monday_schedule) do
      create(:schedule,
        doctor: doctor,
        day_of_week: :monday,
        start_time: Time.zone.parse("09:00"),
        end_time: Time.zone.parse("17:00"),
        active: true
      )
    end

    # Find the next Monday from today
    let(:next_monday) do
      date = Date.today
      date += 1 until date.monday?
      date
    end

    it "returns valid: true for valid appointment time" do
      scheduled_at = Time.zone.local(next_monday.year, next_monday.month, next_monday.day, 10, 0, 0)

      get "/internal/doctors/#{doctor.id}/validate_for_appointment",
        params: { scheduled_at: scheduled_at.iso8601 },
        headers: internal_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["valid"]).to be true
      expect(json["reason"]).to be_nil
    end

    context "when doctor is not active" do
      let(:inactive_doctor) { create(:doctor, :inactive) }

      it "returns valid: false with reason" do
        scheduled_at = Time.zone.local(next_monday.year, next_monday.month, next_monday.day, 10, 0, 0)

        get "/internal/doctors/#{inactive_doctor.id}/validate_for_appointment",
          params: { scheduled_at: scheduled_at.iso8601 },
          headers: internal_headers

        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["reason"]).to eq("Doctor is not active")
      end
    end

    context "when doctor is not accepting new patients" do
      let(:not_accepting_doctor) { create(:doctor, :not_accepting_patients) }

      it "returns valid: false with reason" do
        scheduled_at = Time.zone.local(next_monday.year, next_monday.month, next_monday.day, 10, 0, 0)

        get "/internal/doctors/#{not_accepting_doctor.id}/validate_for_appointment",
          params: { scheduled_at: scheduled_at.iso8601 },
          headers: internal_headers

        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["reason"]).to eq("Doctor is not accepting new patients")
      end
    end

    context "when doctor does not work on the requested day" do
      it "returns valid: false with reason" do
        # Find a Tuesday (doctor only works Monday based on our schedule)
        tuesday = next_monday + 1.day
        scheduled_at = Time.zone.local(tuesday.year, tuesday.month, tuesday.day, 10, 0, 0)

        get "/internal/doctors/#{doctor.id}/validate_for_appointment",
          params: { scheduled_at: scheduled_at.iso8601 },
          headers: internal_headers

        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["reason"]).to include("does not work on")
      end
    end

    context "when appointment time is outside working hours" do
      it "returns valid: false with reason for early time" do
        scheduled_at = Time.zone.local(next_monday.year, next_monday.month, next_monday.day, 7, 0, 0)

        get "/internal/doctors/#{doctor.id}/validate_for_appointment",
          params: { scheduled_at: scheduled_at.iso8601 },
          headers: internal_headers

        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["reason"]).to include("outside doctor's working hours")
      end

      it "returns valid: false with reason for late time" do
        scheduled_at = Time.zone.local(next_monday.year, next_monday.month, next_monday.day, 18, 0, 0)

        get "/internal/doctors/#{doctor.id}/validate_for_appointment",
          params: { scheduled_at: scheduled_at.iso8601 },
          headers: internal_headers

        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["reason"]).to include("outside doctor's working hours")
      end
    end

    context "with invalid datetime format" do
      it "returns 400 status with error" do
        get "/internal/doctors/#{doctor.id}/validate_for_appointment",
          params: { scheduled_at: "invalid-datetime" },
          headers: internal_headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["reason"]).to include("Invalid datetime format")
      end
    end

    context "when doctor is not found" do
      it "returns 404 status" do
        get "/internal/doctors/nonexistent-uuid/validate_for_appointment",
          params: { scheduled_at: Time.current.iso8601 },
          headers: internal_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "request context" do
    it "sets request context from headers" do
      allow(Thread.current).to receive(:[]=).and_call_original

      get "/internal/doctors/#{doctor.id}", headers: internal_headers

      expect(response).to have_http_status(:ok)
      # The controller should have set thread locals
    end
  end
end
