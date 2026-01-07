# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Doctors", type: :request do
  let!(:specialty) { create(:specialty, name: "Cardiology") }
  let!(:clinic) { create(:clinic, name: "Heart Center", city: "New York", state: "NY") }
  let!(:doctor) { create(:doctor, specialty: specialty, clinic: clinic, active: true, accepting_new_patients: true) }

  before do
    allow(EventPublisher).to receive(:publish)
  end

  describe "GET /api/v1/doctors" do
    let!(:active_doctor) { doctor }
    let!(:inactive_doctor) { create(:doctor, :inactive) }

    it "returns a list of active doctors" do
      get "/api/v1/doctors"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctors"].length).to eq(1)
      expect(json["doctors"].first["id"]).to eq(active_doctor.id)
    end

    it "includes specialty and clinic information" do
      get "/api/v1/doctors"

      json = JSON.parse(response.body)
      doctor_data = json["doctors"].first

      expect(doctor_data["specialty"]["name"]).to eq("Cardiology")
      expect(doctor_data["clinic"]["name"]).to eq("Heart Center")
    end

    it "includes average_rating and total_reviews" do
      create(:review, doctor: active_doctor, rating: 5)
      create(:review, doctor: active_doctor, rating: 4)

      get "/api/v1/doctors"

      json = JSON.parse(response.body)
      doctor_data = json["doctors"].first

      expect(doctor_data["average_rating"]).to eq(4.5)
      expect(doctor_data["total_reviews"]).to eq(2)
    end

    it "returns pagination metadata" do
      get "/api/v1/doctors"

      json = JSON.parse(response.body)

      expect(json["meta"]).to include(
        "current_page" => 1,
        "total_pages" => 1,
        "total_count" => 1
      )
    end

    context "with filters" do
      let!(:another_specialty) { create(:specialty, name: "Dermatology") }
      let!(:another_clinic) { create(:clinic, name: "Skin Care", city: "Los Angeles") }
      let!(:dermatologist) { create(:doctor, specialty: another_specialty, clinic: another_clinic) }

      it "filters by specialty_id" do
        get "/api/v1/doctors", params: { specialty_id: specialty.id }

        json = JSON.parse(response.body)
        expect(json["doctors"].length).to eq(1)
        expect(json["doctors"].first["specialty"]["name"]).to eq("Cardiology")
      end

      it "filters by clinic_id" do
        get "/api/v1/doctors", params: { clinic_id: clinic.id }

        json = JSON.parse(response.body)
        expect(json["doctors"].length).to eq(1)
        expect(json["doctors"].first["clinic"]["name"]).to eq("Heart Center")
      end

      it "filters by accepting_patients" do
        not_accepting = create(:doctor, :not_accepting_patients)

        get "/api/v1/doctors", params: { accepting_patients: "true" }

        json = JSON.parse(response.body)
        doctor_ids = json["doctors"].map { |d| d["id"] }

        expect(doctor_ids).to include(active_doctor.id)
        expect(doctor_ids).not_to include(not_accepting.id)
      end

      it "filters by language" do
        spanish_doctor = create(:doctor, languages: [ "English", "Spanish" ])
        french_doctor = create(:doctor, languages: [ "English", "French" ])

        get "/api/v1/doctors", params: { language: "Spanish" }

        json = JSON.parse(response.body)
        doctor_ids = json["doctors"].map { |d| d["id"] }

        expect(doctor_ids).to include(spanish_doctor.id)
        expect(doctor_ids).not_to include(french_doctor.id)
      end
    end

    context "with pagination" do
      before do
        create_list(:doctor, 30, active: true)
      end

      it "paginates results with default per_page of 25" do
        get "/api/v1/doctors"

        json = JSON.parse(response.body)
        expect(json["doctors"].length).to eq(25)
        expect(json["meta"]["total_count"]).to eq(31) # 30 + 1 original
      end

      it "accepts custom per_page parameter" do
        get "/api/v1/doctors", params: { per_page: 10 }

        json = JSON.parse(response.body)
        expect(json["doctors"].length).to eq(10)
      end

      it "accepts page parameter" do
        get "/api/v1/doctors", params: { page: 2, per_page: 10 }

        json = JSON.parse(response.body)
        expect(json["meta"]["current_page"]).to eq(2)
      end
    end
  end

  describe "GET /api/v1/doctors/:id" do
    it "returns a single doctor" do
      get "/api/v1/doctors/#{doctor.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctor"]["id"]).to eq(doctor.id)
    end

    it "includes specialty details" do
      get "/api/v1/doctors/#{doctor.id}"

      json = JSON.parse(response.body)
      expect(json["doctor"]["specialty"]["name"]).to eq("Cardiology")
      expect(json["doctor"]["specialty"]).to have_key("description")
    end

    it "includes clinic details" do
      get "/api/v1/doctors/#{doctor.id}"

      json = JSON.parse(response.body)
      clinic_data = json["doctor"]["clinic"]

      expect(clinic_data["name"]).to eq("Heart Center")
      expect(clinic_data).to have_key("address")
      expect(clinic_data).to have_key("city")
      expect(clinic_data).to have_key("state")
      expect(clinic_data).to have_key("zip_code")
      expect(clinic_data).to have_key("phone_number")
    end

    it "includes schedules" do
      create(:schedule, doctor: doctor, day_of_week: :monday)

      get "/api/v1/doctors/#{doctor.id}"

      json = JSON.parse(response.body)
      expect(json["doctor"]["schedules"]).to be_an(Array)
      expect(json["doctor"]["schedules"].length).to eq(1)
    end

    it "includes average_rating and total_reviews" do
      create(:review, doctor: doctor, rating: 5)

      get "/api/v1/doctors/#{doctor.id}"

      json = JSON.parse(response.body)
      expect(json["doctor"]["average_rating"]).to eq(5.0)
      expect(json["doctor"]["total_reviews"]).to eq(1)
    end

    context "when doctor is not found" do
      it "returns 404 status" do
        get "/api/v1/doctors/nonexistent-uuid"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Doctor not found")
      end
    end

    context "when doctor is inactive" do
      let(:inactive_doctor) { create(:doctor, :inactive) }

      it "returns 404 status" do
        get "/api/v1/doctors/#{inactive_doctor.id}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/doctors/search" do
    let!(:cardiologist) do
      create(:doctor,
        first_name: "John",
        last_name: "Smith",
        specialty: specialty,
        clinic: clinic
      )
    end

    let!(:dermatologist) do
      create(:doctor,
        first_name: "Jane",
        last_name: "Doe",
        specialty: create(:specialty, name: "Dermatology"),
        clinic: create(:clinic, name: "Skin Clinic", city: "Boston")
      )
    end

    it "searches doctors by query" do
      get "/api/v1/doctors/search", params: { query: "John" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      doctor_names = json["doctors"].map { |d| d["first_name"] }
      expect(doctor_names).to include("John")
    end

    it "searches by specialty name" do
      get "/api/v1/doctors/search", params: { query: "Cardiology" }

      json = JSON.parse(response.body)
      specialties = json["doctors"].map { |d| d["specialty"]["name"] }
      expect(specialties).to include("Cardiology")
    end

    it "searches by clinic name" do
      get "/api/v1/doctors/search", params: { query: "Heart Center" }

      json = JSON.parse(response.body)
      clinics = json["doctors"].map { |d| d["clinic"]["name"] }
      expect(clinics).to include("Heart Center")
    end

    it "combines search with filters" do
      get "/api/v1/doctors/search", params: {
        query: "John",
        specialty_id: specialty.id
      }

      json = JSON.parse(response.body)
      expect(json["doctors"]).to all(
        include("specialty" => hash_including("id" => specialty.id))
      )
    end

    it "filters by language in search" do
      spanish_doctor = create(:doctor, languages: [ "Spanish" ])

      get "/api/v1/doctors/search", params: { language: "Spanish" }

      json = JSON.parse(response.body)
      doctor_ids = json["doctors"].map { |d| d["id"] }
      expect(doctor_ids).to include(spanish_doctor.id)
    end

    it "filters by accepting_patients in search" do
      get "/api/v1/doctors/search", params: { accepting_patients: "true" }

      json = JSON.parse(response.body)
      # All returned doctors should be accepting new patients
      expect(json["doctors"]).to all(
        include("accepting_new_patients" => true)
      )
    end

    it "returns pagination metadata" do
      get "/api/v1/doctors/search", params: { query: "John" }

      json = JSON.parse(response.body)
      expect(json["meta"]).to include(
        "current_page",
        "total_pages",
        "total_count"
      )
    end

    context "without query parameter" do
      it "returns all active doctors" do
        get "/api/v1/doctors/search"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Should include all active doctors from this test
        expect(json["doctors"].length).to be >= 1
      end
    end
  end

  describe "GET /api/v1/doctors/:id/availability" do
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

    it "returns available time slots for today" do
      get "/api/v1/doctors/#{doctor.id}/availability"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["doctor_id"]).to eq(doctor.id)
      expect(json["date"]).to eq(Date.today.to_s)
      expect(json["available_slots"]).to be_an(Array)
    end

    it "returns slots for a specific date" do
      # Find a day that matches the schedule
      target_date = Date.today
      get "/api/v1/doctors/#{doctor.id}/availability", params: { date: target_date.to_s }

      json = JSON.parse(response.body)
      expect(json["date"]).to eq(target_date.to_s)
    end

    it "includes next_available_date" do
      get "/api/v1/doctors/#{doctor.id}/availability"

      json = JSON.parse(response.body)
      expect(json).to have_key("next_available_date")
    end

    it "returns slot structure with start_time, end_time, and duration" do
      get "/api/v1/doctors/#{doctor.id}/availability"

      json = JSON.parse(response.body)

      if json["available_slots"].any?
        slot = json["available_slots"].first
        expect(slot).to have_key("start_time")
        expect(slot).to have_key("end_time")
        expect(slot).to have_key("duration_minutes")
      end
    end

    context "with invalid date format" do
      it "returns 400 status" do
        get "/api/v1/doctors/#{doctor.id}/availability", params: { date: "invalid-date" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid date format")
      end
    end

    context "when doctor is not found" do
      it "returns 404 status" do
        get "/api/v1/doctors/nonexistent-uuid/availability"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/doctors/:id/reviews" do
    before do
      create_list(:review, 5, doctor: doctor)
    end

    it "returns paginated reviews for the doctor" do
      get "/api/v1/doctors/#{doctor.id}/reviews"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["reviews"]).to be_an(Array)
      expect(json["reviews"].length).to eq(5)
    end

    it "returns reviews in recent order" do
      old_review = create(:review, doctor: doctor, created_at: 1.week.ago)
      new_review = create(:review, doctor: doctor, created_at: 1.day.ago)

      get "/api/v1/doctors/#{doctor.id}/reviews"

      json = JSON.parse(response.body)
      review_ids = json["reviews"].map { |r| r["id"] }

      expect(review_ids.index(new_review.id)).to be < review_ids.index(old_review.id)
    end

    it "returns pagination metadata" do
      get "/api/v1/doctors/#{doctor.id}/reviews"

      json = JSON.parse(response.body)
      expect(json["meta"]).to include(
        "current_page",
        "total_pages",
        "total_count"
      )
    end

    it "returns review stats" do
      get "/api/v1/doctors/#{doctor.id}/reviews"

      json = JSON.parse(response.body)
      expect(json["stats"]).to include(
        "average_rating",
        "total_reviews"
      )
    end

    it "accepts pagination parameters" do
      create_list(:review, 30, doctor: doctor)

      get "/api/v1/doctors/#{doctor.id}/reviews", params: { page: 2, per_page: 10 }

      json = JSON.parse(response.body)
      expect(json["meta"]["current_page"]).to eq(2)
    end

    context "when doctor is not found" do
      it "returns 404 status" do
        get "/api/v1/doctors/nonexistent-uuid/reviews"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/doctors/specialties" do
    before do
      # Create specialties with doctors
      specialty_with_doctors = create(:specialty, name: "Internal Medicine")
      create(:doctor, specialty: specialty_with_doctors)

      specialty_without_doctors = create(:specialty, name: "Surgery")
    end

    it "returns specialties that have doctors" do
      get "/api/v1/doctors/specialties"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      specialty_names = json["specialties"].map { |s| s["name"] }

      # Should include specialties with doctors
      expect(specialty_names).to include("Cardiology") # From the main doctor setup
      expect(specialty_names).to include("Internal Medicine")

      # Should not include specialties without doctors
      expect(specialty_names).not_to include("Surgery")
    end

    it "returns specialties ordered by name" do
      get "/api/v1/doctors/specialties"

      json = JSON.parse(response.body)
      names = json["specialties"].map { |s| s["name"] }

      expect(names).to eq(names.sort)
    end

    it "includes doctors_count for each specialty" do
      get "/api/v1/doctors/specialties"

      json = JSON.parse(response.body)
      specialty_data = json["specialties"].find { |s| s["name"] == "Cardiology" }

      expect(specialty_data).to have_key("doctors_count")
      expect(specialty_data["doctors_count"]).to be >= 1
    end
  end
end
