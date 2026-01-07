# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clinic, type: :model do
  describe "associations" do
    it { should have_many(:doctors).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { build(:clinic) }

    it { should validate_presence_of(:name) }

    describe "phone_number format" do
      it "accepts valid phone numbers" do
        valid_numbers = [
          "+1 (555) 123-4567",
          "555-123-4567",
          "(555) 123 4567",
          "+44 20 7946 0958",
          "5551234567"
        ]

        valid_numbers.each do |number|
          clinic = build(:clinic, phone_number: number)
          expect(clinic).to be_valid, "Expected #{number} to be valid"
        end
      end

      it "allows blank phone numbers" do
        clinic = build(:clinic, phone_number: "")
        expect(clinic).to be_valid
      end

      it "allows nil phone numbers" do
        clinic = build(:clinic, phone_number: nil)
        expect(clinic).to be_valid
      end

      it "rejects invalid phone numbers" do
        invalid_numbers = [
          "abc-def-ghij",
          "phone: 555-1234",
          "@#$%^&*"
        ]

        invalid_numbers.each do |number|
          clinic = build(:clinic, phone_number: number)
          expect(clinic).not_to be_valid, "Expected #{number} to be invalid"
          expect(clinic.errors[:phone_number]).to be_present
        end
      end
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active clinics" do
        active_clinic = create(:clinic, active: true)
        create(:clinic, :inactive)

        expect(Clinic.active).to eq([ active_clinic ])
      end
    end

    describe ".by_city" do
      let!(:new_york) { create(:clinic, city: "New York") }
      let!(:los_angeles) { create(:clinic, city: "Los Angeles") }

      it "filters by city" do
        expect(Clinic.by_city("New York")).to eq([ new_york ])
      end

      it "returns all clinics when city is blank" do
        expect(Clinic.by_city(nil)).to include(new_york, los_angeles)
        expect(Clinic.by_city("")).to include(new_york, los_angeles)
      end
    end

    describe ".by_state" do
      let!(:california) { create(:clinic, state: "CA") }
      let!(:new_york) { create(:clinic, state: "NY") }

      it "filters by state" do
        expect(Clinic.by_state("CA")).to eq([ california ])
      end

      it "returns all clinics when state is blank" do
        expect(Clinic.by_state(nil)).to include(california, new_york)
        expect(Clinic.by_state("")).to include(california, new_york)
      end
    end

    describe ".search_by_name" do
      let!(:mayo_clinic) { create(:clinic, name: "Mayo Clinic") }
      let!(:cleveland_clinic) { create(:clinic, name: "Cleveland Clinic") }
      let!(:general_hospital) { create(:clinic, name: "General Hospital") }

      it "searches clinics by name (case insensitive)" do
        expect(Clinic.search_by_name("mayo")).to include(mayo_clinic)
        expect(Clinic.search_by_name("MAYO")).to include(mayo_clinic)
      end

      it "returns partial matches" do
        expect(Clinic.search_by_name("clinic")).to include(mayo_clinic, cleveland_clinic)
        expect(Clinic.search_by_name("clinic")).not_to include(general_hospital)
      end

      it "returns all clinics when query is blank" do
        expect(Clinic.search_by_name(nil).count).to eq(3)
        expect(Clinic.search_by_name("").count).to eq(3)
      end
    end
  end

  describe "instance methods" do
    describe "#full_address" do
      it "returns full address with all components" do
        clinic = build(:clinic,
          address: "123 Main St",
          city: "New York",
          state: "NY",
          zip_code: "10001"
        )

        expect(clinic.full_address).to eq("123 Main St, New York, NY, 10001")
      end

      it "handles missing address components" do
        clinic = build(:clinic,
          address: nil,
          city: "New York",
          state: "NY",
          zip_code: nil
        )

        expect(clinic.full_address).to eq("New York, NY")
      end

      it "handles all nil components" do
        clinic = build(:clinic,
          address: nil,
          city: nil,
          state: nil,
          zip_code: nil
        )

        expect(clinic.full_address).to eq("")
      end
    end
  end

  describe "dependent restriction" do
    let(:clinic) { create(:clinic) }

    context "when clinic has doctors" do
      before { create(:doctor, clinic: clinic) }

      it "prevents deletion" do
        expect { clinic.destroy }.not_to change(Clinic, :count)
      end

      it "adds an error on base" do
        clinic.destroy
        expect(clinic.errors[:base]).to include(/Cannot delete record/)
      end
    end

    context "when clinic has no doctors" do
      it "allows deletion" do
        empty_clinic = create(:clinic)
        expect { empty_clinic.destroy }.to change(Clinic, :count).by(-1)
      end
    end
  end

  describe "factory" do
    it "has valid factory" do
      expect(build(:clinic)).to be_valid
    end

    it "has valid inactive trait" do
      expect(build(:clinic, :inactive)).to be_valid
      expect(build(:clinic, :inactive).active).to be false
    end
  end
end
