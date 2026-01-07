# frozen_string_literal: true

require "rails_helper"

RSpec.describe Review, type: :model do
  describe "associations" do
    it { should belong_to(:doctor) }
  end

  describe "validations" do
    subject { build(:review) }

    it { should validate_presence_of(:doctor) }
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:rating) }

    describe "rating numericality" do
      it { should validate_numericality_of(:rating).only_integer }

      it "accepts rating of 1" do
        review = build(:review, rating: 1)
        expect(review).to be_valid
      end

      it "accepts rating of 5" do
        review = build(:review, rating: 5)
        expect(review).to be_valid
      end

      it "rejects rating of 0" do
        review = build(:review, rating: 0)
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to be_present
      end

      it "rejects rating of 6" do
        review = build(:review, rating: 6)
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to be_present
      end

      it "rejects negative rating" do
        review = build(:review, rating: -1)
        expect(review).not_to be_valid
      end

      it "rejects decimal rating" do
        review = build(:review, rating: 3.5)
        expect(review).not_to be_valid
      end
    end

    describe "user_id uniqueness per doctor" do
      let(:doctor) { create(:doctor) }

      it "allows same user to review different doctors" do
        user_id = SecureRandom.uuid
        create(:review, user_id: user_id, doctor: doctor)

        another_doctor = create(:doctor)
        review = build(:review, user_id: user_id, doctor: another_doctor)

        expect(review).to be_valid
      end

      it "prevents same user from reviewing same doctor twice" do
        user_id = SecureRandom.uuid
        create(:review, user_id: user_id, doctor: doctor)

        duplicate_review = build(:review, user_id: user_id, doctor: doctor)

        expect(duplicate_review).not_to be_valid
        expect(duplicate_review.errors[:user_id]).to include("has already reviewed this doctor")
      end
    end
  end

  describe "scopes" do
    describe ".verified_reviews" do
      it "returns only verified reviews" do
        verified = create(:review, :verified)
        create(:review, verified: false)

        expect(Review.verified_reviews).to eq([ verified ])
      end
    end

    describe ".recent" do
      it "orders reviews by created_at descending" do
        old_review = create(:review, created_at: 1.week.ago)
        new_review = create(:review, created_at: 1.day.ago)
        newest_review = create(:review, created_at: 1.hour.ago)

        expect(Review.recent.to_a).to eq([ newest_review, new_review, old_review ])
      end
    end

    describe ".by_rating" do
      let!(:five_star) { create(:review, rating: 5) }
      let!(:four_star) { create(:review, rating: 4) }
      let!(:three_star) { create(:review, rating: 3) }

      it "filters by specific rating" do
        expect(Review.by_rating(5)).to eq([ five_star ])
      end

      it "returns all reviews when rating is blank" do
        expect(Review.by_rating(nil).count).to eq(3)
        expect(Review.by_rating("").count).to eq(3)
      end
    end

    describe ".high_rated" do
      let!(:five_star) { create(:review, rating: 5) }
      let!(:four_star) { create(:review, rating: 4) }
      let!(:three_star) { create(:review, rating: 3) }
      let!(:two_star) { create(:review, rating: 2) }

      it "returns reviews with rating >= 4" do
        expect(Review.high_rated).to include(five_star, four_star)
        expect(Review.high_rated).not_to include(three_star, two_star)
      end
    end
  end

  describe "callbacks" do
    describe "after_create" do
      let(:doctor) { create(:doctor) }

      describe "#publish_review_created_event" do
        it "publishes event after creation" do
          allow(EventPublisher).to receive(:publish)

          review = create(:review, doctor: doctor, rating: 5)

          expect(EventPublisher).to have_received(:publish).with(
            "review.created",
            hash_including(
              review_id: review.id,
              doctor_id: doctor.id,
              rating: 5
            )
          )
        end

        it "handles event publishing errors gracefully" do
          allow(EventPublisher).to receive(:publish).and_raise(StandardError.new("Connection failed"))
          allow(Rails.logger).to receive(:error)

          expect { create(:review, doctor: doctor) }.not_to raise_error

          expect(Rails.logger).to have_received(:error).with(/Failed to publish review.created event/)
        end
      end

      describe "#update_doctor_cache" do
        it "logs review creation" do
          allow(Rails.logger).to receive(:info)
          allow(EventPublisher).to receive(:publish)

          create(:review, doctor: doctor)

          expect(Rails.logger).to have_received(:info).with(/Review created for doctor #{doctor.id}/)
        end
      end
    end
  end

  describe "factory" do
    it "has valid factory" do
      expect(build(:review)).to be_valid
    end

    it "has valid verified trait" do
      review = build(:review, :verified)
      expect(review).to be_valid
      expect(review.verified).to be true
    end

    it "has valid high_rated trait" do
      review = build(:review, :high_rated)
      expect(review).to be_valid
      expect(review.rating).to be >= 4
    end

    it "has valid low_rated trait" do
      review = build(:review, :low_rated)
      expect(review).to be_valid
      expect(review.rating).to be <= 2
    end
  end
end
