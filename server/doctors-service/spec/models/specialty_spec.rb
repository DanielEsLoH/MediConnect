# frozen_string_literal: true

require "rails_helper"

RSpec.describe Specialty, type: :model do
  describe "associations" do
    it { should have_many(:doctors).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:specialty) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }

    context "with duplicate name" do
      before { create(:specialty, name: "Cardiology") }

      it "rejects duplicate names" do
        specialty = build(:specialty, name: "Cardiology")
        expect(specialty).not_to be_valid
        expect(specialty.errors[:name]).to include("has already been taken")
      end
    end
  end

  describe "scopes" do
    describe ".with_doctors" do
      it "returns specialties that have doctors" do
        specialty_with_doctors = create(:specialty)
        create(:doctor, specialty: specialty_with_doctors)

        specialty_without_doctors = create(:specialty)

        expect(Specialty.with_doctors).to include(specialty_with_doctors)
        expect(Specialty.with_doctors).not_to include(specialty_without_doctors)
      end

      it "returns distinct specialties" do
        specialty = create(:specialty)
        create_list(:doctor, 3, specialty: specialty)

        expect(Specialty.with_doctors.count).to eq(1)
      end
    end

    describe ".by_name" do
      let!(:cardiology) { create(:specialty, name: "Cardiology") }
      let!(:dermatology) { create(:specialty, name: "Dermatology") }
      let!(:neurology) { create(:specialty, name: "Neurology") }

      it "filters specialties by name (case insensitive)" do
        expect(Specialty.by_name("cardio")).to include(cardiology)
        expect(Specialty.by_name("CARDIO")).to include(cardiology)
      end

      it "returns partial matches" do
        expect(Specialty.by_name("ology")).to include(cardiology, dermatology, neurology)
      end

      it "returns all specialties when name is blank" do
        expect(Specialty.by_name(nil).count).to eq(3)
        expect(Specialty.by_name("").count).to eq(3)
      end
    end
  end

  describe "instance methods" do
    describe "#doctors_count" do
      let(:specialty) { create(:specialty) }

      it "returns count of active doctors" do
        create_list(:doctor, 3, specialty: specialty, active: true)
        create(:doctor, :inactive, specialty: specialty)

        expect(specialty.doctors_count).to eq(3)
      end

      it "returns 0 when no active doctors" do
        create(:doctor, :inactive, specialty: specialty)

        expect(specialty.doctors_count).to eq(0)
      end

      it "returns 0 when no doctors at all" do
        expect(specialty.doctors_count).to eq(0)
      end
    end
  end

  describe "dependent restriction" do
    let(:specialty) { create(:specialty) }

    context "when specialty has doctors" do
      before { create(:doctor, specialty: specialty) }

      it "prevents deletion" do
        expect { specialty.destroy }.not_to change(Specialty, :count)
      end

      it "adds an error on base" do
        specialty.destroy
        expect(specialty.errors[:base]).to include(/Cannot delete record/)
      end
    end

    context "when specialty has no doctors" do
      it "allows deletion" do
        empty_specialty = create(:specialty)
        expect { empty_specialty.destroy }.to change(Specialty, :count).by(-1)
      end
    end
  end
end