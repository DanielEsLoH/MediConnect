# frozen_string_literal: true

require "rails_helper"

RSpec.describe Allergy, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:allergen) }
    it { should validate_presence_of(:severity) }
  end

  describe "enums" do
    it "defines severity enum" do
      expect(Allergy.severities.keys).to match_array(
        %w[mild moderate severe life_threatening]
      )
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }

    describe ".by_severity" do
      it "filters by severity level" do
        severe_allergy = create(:allergy, :severe, user: user)
        create(:allergy, :mild, user: user)

        expect(Allergy.by_severity(:severe)).to eq([ severe_allergy ])
      end
    end

    describe ".active_allergies" do
      it "returns only active allergies" do
        active = create(:allergy, user: user, active: true)
        create(:allergy, :inactive, user: user)

        expect(Allergy.active_allergies).to eq([ active ])
      end
    end

    describe ".critical" do
      it "returns severe and life_threatening allergies" do
        severe = create(:allergy, :severe, user: user)
        life_threatening = create(:allergy, :life_threatening, user: user)
        create(:allergy, :mild, user: user)

        expect(Allergy.critical).to match_array([ severe, life_threatening ])
      end
    end
  end

  describe "event publishing" do
    let(:event_publisher) { class_double(EventPublisher).as_stubbed_const }

    it "publishes allergy.created event on create" do
      allow(event_publisher).to receive(:publish)

      allergy = create(:allergy)

      expect(event_publisher).to have_received(:publish).with(
        "allergy.created",
        hash_including(
          allergy_id: allergy.id,
          user_id: allergy.user_id,
          allergen: allergy.allergen,
          severity: allergy.severity
        )
      )
    end
  end
end
