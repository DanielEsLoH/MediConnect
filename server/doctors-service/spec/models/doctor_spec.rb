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
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:license_number) }

    it "validates email uniqueness" do
      create(:doctor, email: "doctor@example.com")
      doctor = build(:doctor, email: "doctor@example.com")
      expect(doctor).not_to be_valid
    end

    it "validates license_number uniqueness" do
      create(:doctor, license_number: "ABC123")
      doctor = build(:doctor, license_number: "ABC123")
      expect(doctor).not_to be_valid
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
      let(:doctor) { create(:doctor, :with_reviews) }

      it "calculates average rating" do
        expect(doctor.average_rating).to be_a(Float)
        expect(doctor.average_rating).to be_between(0, 5)
      end
    end

    describe "#total_reviews" do
      let(:doctor) { create(:doctor) }

      it "returns count of reviews" do
        create_list(:review, 3, doctor: doctor)
        expect(doctor.total_reviews).to eq(3)
      end
    end
  end
end
