# frozen_string_literal: true

require "rails_helper"

RSpec.describe Doctor, type: :model do
  describe "associations" do
    it { should belong_to(:specialty) }
    it { should belong_to(:clinic) }
    it { should have_many(:schedules).dependent(:destroy) }
    it { should have_many(:reviews).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:doctor) }

    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:license_number) }

    describe "email validations" do
      it "validates email uniqueness" do
        create(:doctor, email: "doctor@example.com")
        doctor = build(:doctor, email: "doctor@example.com")
        expect(doctor).not_to be_valid
        expect(doctor.errors[:email]).to include("has already been taken")
      end

      it "validates email uniqueness case insensitively" do
        create(:doctor, email: "Doctor@Example.com")
        doctor = build(:doctor, email: "doctor@example.com")
        expect(doctor).not_to be_valid
      end

      it "accepts valid email formats" do
        valid_emails = [
          "user@example.com",
          "user.name@example.com",
          "user+tag@example.com",
          "user@subdomain.example.com"
        ]

        valid_emails.each do |email|
          doctor = build(:doctor, email: email)
          expect(doctor).to be_valid, "Expected #{email} to be valid"
        end
      end

      it "rejects invalid email formats" do
        invalid_emails = [
          "invalid",
          "invalid@",
          "@example.com",
          "user@.com",
          "user"
        ]

        invalid_emails.each do |email|
          doctor = build(:doctor, email: email)
          expect(doctor).not_to be_valid, "Expected #{email} to be invalid"
          expect(doctor.errors[:email]).to be_present
        end
      end
    end

    describe "license_number validations" do
      it "validates license_number uniqueness" do
        create(:doctor, license_number: "ABC123")
        doctor = build(:doctor, license_number: "ABC123")
        expect(doctor).not_to be_valid
        expect(doctor.errors[:license_number]).to include("has already been taken")
      end
    end

    describe "phone_number format" do
      it "accepts valid phone numbers" do
        valid_numbers = [
          "+1 (555) 123-4567",
          "555-123-4567",
          "(555) 123 4567"
        ]

        valid_numbers.each do |number|
          doctor = build(:doctor, phone_number: number)
          expect(doctor).to be_valid, "Expected #{number} to be valid"
        end
      end

      it "allows blank phone numbers" do
        doctor = build(:doctor, phone_number: "")
        expect(doctor).to be_valid
      end

      it "rejects invalid phone numbers" do
        doctor = build(:doctor, phone_number: "abc-def-ghij")
        expect(doctor).not_to be_valid
        expect(doctor.errors[:phone_number]).to be_present
      end
    end

    describe "years_of_experience numericality" do
      it "accepts positive values" do
        doctor = build(:doctor, years_of_experience: 10)
        expect(doctor).to be_valid
      end

      it "accepts zero" do
        doctor = build(:doctor, years_of_experience: 0)
        expect(doctor).to be_valid
      end

      it "accepts nil" do
        doctor = build(:doctor, years_of_experience: nil)
        expect(doctor).to be_valid
      end

      it "rejects negative values" do
        doctor = build(:doctor, years_of_experience: -1)
        expect(doctor).not_to be_valid
        expect(doctor.errors[:years_of_experience]).to be_present
      end
    end

    describe "consultation_fee numericality" do
      it "accepts positive values" do
        doctor = build(:doctor, consultation_fee: 100.50)
        expect(doctor).to be_valid
      end

      it "accepts nil" do
        doctor = build(:doctor, consultation_fee: nil)
        expect(doctor).to be_valid
      end

      it "rejects zero" do
        doctor = build(:doctor, consultation_fee: 0)
        expect(doctor).not_to be_valid
        expect(doctor.errors[:consultation_fee]).to be_present
      end

      it "rejects negative values" do
        doctor = build(:doctor, consultation_fee: -50)
        expect(doctor).not_to be_valid
        expect(doctor.errors[:consultation_fee]).to be_present
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active doctors" do
        active_doctor = create(:doctor, active: true)
        create(:doctor, :inactive)

        expect(Doctor.active).to eq([ active_doctor ])
      end
    end

    describe ".accepting_patients" do
      it "returns doctors accepting new patients" do
        accepting = create(:doctor, accepting_new_patients: true)
        create(:doctor, :not_accepting_patients)

        expect(Doctor.accepting_patients).to eq([ accepting ])
      end
    end

    describe ".by_specialty" do
      it "filters by specialty" do
        specialty = create(:specialty)
        doctor = create(:doctor, specialty: specialty)
        create(:doctor)

        expect(Doctor.by_specialty(specialty.id)).to eq([ doctor ])
      end

      it "returns all doctors when specialty_id is blank" do
        create_list(:doctor, 3)

        expect(Doctor.by_specialty(nil).count).to eq(3)
        expect(Doctor.by_specialty("").count).to eq(3)
      end
    end

    describe ".by_clinic" do
      it "filters by clinic" do
        clinic = create(:clinic)
        doctor = create(:doctor, clinic: clinic)
        create(:doctor)

        expect(Doctor.by_clinic(clinic.id)).to eq([ doctor ])
      end

      it "returns all doctors when clinic_id is blank" do
        create_list(:doctor, 3)

        expect(Doctor.by_clinic(nil).count).to eq(3)
        expect(Doctor.by_clinic("").count).to eq(3)
      end
    end

    describe ".by_language" do
      let!(:spanish_doctor) { create(:doctor, languages: [ "English", "Spanish" ]) }
      let!(:french_doctor) { create(:doctor, languages: [ "English", "French" ]) }
      let!(:english_only) { create(:doctor, languages: [ "English" ]) }

      it "filters by language" do
        expect(Doctor.by_language("Spanish")).to eq([ spanish_doctor ])
        expect(Doctor.by_language("French")).to eq([ french_doctor ])
      end

      it "returns all doctors when language is blank" do
        expect(Doctor.by_language(nil).count).to eq(3)
        expect(Doctor.by_language("").count).to eq(3)
      end
    end

    describe ".with_min_rating" do
      let(:high_rated_doctor) { create(:doctor) }
      let(:low_rated_doctor) { create(:doctor) }

      before do
        create(:review, doctor: high_rated_doctor, rating: 5)
        create(:review, doctor: high_rated_doctor, rating: 5)
        create(:review, doctor: low_rated_doctor, rating: 2)
        create(:review, doctor: low_rated_doctor, rating: 2)
      end

      it "filters doctors with minimum average rating" do
        expect(Doctor.with_min_rating(4)).to include(high_rated_doctor)
        expect(Doctor.with_min_rating(4)).not_to include(low_rated_doctor)
      end
    end
  end

  describe "callbacks" do
    describe "before_validation" do
      describe "#normalize_email" do
        it "downcases email" do
          doctor = create(:doctor, email: "Doctor@Example.COM")
          expect(doctor.reload.email).to eq("doctor@example.com")
        end

        it "strips whitespace from email" do
          doctor = create(:doctor, email: "  doctor@example.com  ")
          expect(doctor.reload.email).to eq("doctor@example.com")
        end

        it "handles nil email" do
          doctor = build(:doctor, email: nil)
          expect { doctor.valid? }.not_to raise_error
        end
      end
    end

    describe "after_create" do
      describe "#publish_doctor_created_event" do
        it "publishes event after creation" do
          allow(EventPublisher).to receive(:publish)

          doctor = create(:doctor)

          expect(EventPublisher).to have_received(:publish).with(
            "doctor.created",
            hash_including(
              doctor_id: doctor.id,
              specialty_id: doctor.specialty_id,
              clinic_id: doctor.clinic_id,
              full_name: doctor.full_name,
              email: doctor.email
            )
          )
        end

        it "handles event publishing errors gracefully" do
          allow(EventPublisher).to receive(:publish).and_raise(StandardError.new("Connection failed"))
          allow(Rails.logger).to receive(:error)

          expect { create(:doctor) }.not_to raise_error

          expect(Rails.logger).to have_received(:error).with(/Failed to publish doctor.created event/)
        end
      end
    end

    describe "after_update" do
      describe "#publish_doctor_updated_event" do
        let(:doctor) { create(:doctor) }

        before do
          allow(EventPublisher).to receive(:publish)
        end

        it "publishes event after update" do
          doctor.update(accepting_new_patients: false)

          expect(EventPublisher).to have_received(:publish).with(
            "doctor.updated",
            hash_including(
              doctor_id: doctor.id,
              full_name: doctor.full_name,
              accepting_new_patients: false
            )
          )
        end

        it "handles event publishing errors gracefully" do
          allow(EventPublisher).to receive(:publish)
            .with("doctor.created", anything)
          allow(EventPublisher).to receive(:publish)
            .with("doctor.updated", anything)
            .and_raise(StandardError.new("Connection failed"))
          allow(Rails.logger).to receive(:error)

          expect { doctor.update(first_name: "Updated") }.not_to raise_error

          expect(Rails.logger).to have_received(:error).with(/Failed to publish doctor.updated event/)
        end
      end
    end
  end

  describe "instance methods" do
    describe "#full_name" do
      it "returns concatenated first and last name" do
        doctor = build(:doctor, first_name: "John", last_name: "Doe")
        expect(doctor.full_name).to eq("John Doe")
      end
    end

    describe "#average_rating" do
      let(:doctor) { create(:doctor) }

      context "with reviews" do
        before do
          create(:review, doctor: doctor, rating: 5)
          create(:review, doctor: doctor, rating: 4)
          create(:review, doctor: doctor, rating: 3)
        end

        it "calculates average rating" do
          expect(doctor.average_rating).to eq(4.0)
        end

        it "rounds to 2 decimal places" do
          create(:review, doctor: doctor, rating: 5)
          # (5 + 4 + 3 + 5) / 4 = 4.25
          expect(doctor.average_rating).to eq(4.25)
        end
      end

      context "without reviews" do
        it "returns 0.0" do
          expect(doctor.average_rating).to eq(0.0)
        end
      end
    end

    describe "#total_reviews" do
      let(:doctor) { create(:doctor) }

      it "returns count of reviews" do
        create_list(:review, 3, doctor: doctor)
        expect(doctor.total_reviews).to eq(3)
      end

      it "returns 0 when no reviews" do
        expect(doctor.total_reviews).to eq(0)
      end
    end
  end

  describe "PgSearch" do
    let!(:cardiologist) do
      specialty = create(:specialty, name: "Cardiology")
      clinic = create(:clinic, name: "Heart Center", city: "New York", state: "NY")
      create(:doctor,
        first_name: "John",
        last_name: "Smith",
        bio: "Expert in heart conditions",
        specialty: specialty,
        clinic: clinic
      )
    end

    let!(:dermatologist) do
      specialty = create(:specialty, name: "Dermatology")
      clinic = create(:clinic, name: "Skin Care Clinic", city: "Los Angeles", state: "CA")
      create(:doctor,
        first_name: "Jane",
        last_name: "Doe",
        bio: "Specializes in skin treatments",
        specialty: specialty,
        clinic: clinic
      )
    end

    describe ".search_by_text" do
      it "searches by first name" do
        results = Doctor.search_by_text("John")
        expect(results).to include(cardiologist)
        expect(results).not_to include(dermatologist)
      end

      it "searches by last name" do
        results = Doctor.search_by_text("Smith")
        expect(results).to include(cardiologist)
      end

      it "searches by specialty name" do
        results = Doctor.search_by_text("Cardiology")
        expect(results).to include(cardiologist)
      end

      it "searches by clinic name" do
        results = Doctor.search_by_text("Heart Center")
        expect(results).to include(cardiologist)
      end

      it "searches by clinic city" do
        results = Doctor.search_by_text("New York")
        expect(results).to include(cardiologist)
      end

      it "searches by bio content" do
        results = Doctor.search_by_text("heart conditions")
        expect(results).to include(cardiologist)
      end

      it "supports partial matching with prefix" do
        results = Doctor.search_by_text("Card")
        expect(results).to include(cardiologist)
      end
    end
  end

  describe "factory" do
    it "has valid factory" do
      expect(build(:doctor)).to be_valid
    end

    it "has valid inactive trait" do
      doctor = build(:doctor, :inactive)
      expect(doctor).to be_valid
      expect(doctor.active).to be false
    end

    it "has valid not_accepting_patients trait" do
      doctor = build(:doctor, :not_accepting_patients)
      expect(doctor).to be_valid
      expect(doctor.accepting_new_patients).to be false
    end

    it "has valid with_schedules trait" do
      doctor = create(:doctor, :with_schedules)
      expect(doctor.schedules.count).to eq(5)
    end

    it "has valid with_reviews trait" do
      doctor = create(:doctor, :with_reviews)
      expect(doctor.reviews.count).to eq(5)
    end
  end
end
