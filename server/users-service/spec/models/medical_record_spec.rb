# frozen_string_literal: true

require "rails_helper"

RSpec.describe MedicalRecord, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:user) }
    it { should validate_presence_of(:record_type) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:recorded_at) }
  end

  describe "enums" do
    it "defines record_type enum" do
      expect(MedicalRecord.record_types.keys).to match_array(
        %w[diagnosis prescription lab_result imaging vaccination surgery other]
      )
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }

    describe ".recent" do
      it "orders by recorded_at descending" do
        old_record = create(:medical_record, user: user, recorded_at: 1.month.ago)
        new_record = create(:medical_record, user: user, recorded_at: 1.day.ago)

        expect(MedicalRecord.recent).to eq([ new_record, old_record ])
      end
    end

    describe ".by_type" do
      it "filters by record type" do
        diagnosis = create(:medical_record, :diagnosis, user: user)
        create(:medical_record, :prescription, user: user)

        expect(MedicalRecord.by_type(:diagnosis)).to eq([ diagnosis ])
      end
    end

    describe ".for_date_range" do
      it "filters by date range" do
        in_range = create(:medical_record, user: user, recorded_at: 5.days.ago)
        create(:medical_record, user: user, recorded_at: 15.days.ago)

        result = MedicalRecord.for_date_range(7.days.ago, Date.today)
        expect(result).to eq([ in_range ])
      end
    end
  end

  describe "event publishing" do
    let(:event_publisher) { class_double(EventPublisher).as_stubbed_const }

    it "publishes medical_record.created event on create" do
      allow(event_publisher).to receive(:publish)

      medical_record = create(:medical_record)

      expect(event_publisher).to have_received(:publish).with(
        "medical_record.created",
        hash_including(
          medical_record_id: medical_record.id,
          user_id: medical_record.user_id,
          record_type: medical_record.record_type
        )
      )
    end
  end
end
