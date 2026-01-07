# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment, type: :model do
  # =============================================================================
  # FACTORY VALIDATION
  # =============================================================================
  describe "factory" do
    it "has a valid factory" do
      expect(build(:payment)).to be_valid
    end

    it "has valid traits" do
      expect(build(:payment, :pending)).to be_valid
      expect(build(:payment, :processing)).to be_valid
      expect(build(:payment, :completed)).to be_valid
      expect(build(:payment, :failed)).to be_valid
      expect(build(:payment, :refunded)).to be_valid
      expect(build(:payment, :partially_refunded)).to be_valid
      expect(build(:payment, :debit_card)).to be_valid
      expect(build(:payment, :wallet)).to be_valid
      expect(build(:payment, :insurance)).to be_valid
      expect(build(:payment, :without_appointment)).to be_valid
    end
  end

  # =============================================================================
  # VALIDATIONS
  # =============================================================================
  describe "validations" do
    subject(:payment) { build(:payment) }

    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }

    describe "stripe_payment_intent_id uniqueness" do
      context "when stripe_payment_intent_id is present" do
        it "validates uniqueness" do
          existing = create(:payment, :with_unique_intent)
          duplicate = build(:payment, stripe_payment_intent_id: existing.stripe_payment_intent_id)

          expect(duplicate).not_to be_valid
          expect(duplicate.errors[:stripe_payment_intent_id]).to include("has already been taken")
        end
      end

      context "when stripe_payment_intent_id is nil" do
        it "allows multiple nil values" do
          create(:payment, stripe_payment_intent_id: nil)
          duplicate = build(:payment, stripe_payment_intent_id: nil)

          expect(duplicate).to be_valid
        end
      end
    end

    describe "amount validation" do
      it "rejects zero amount" do
        payment = build(:payment, amount: 0)
        expect(payment).not_to be_valid
        expect(payment.errors[:amount]).to be_present
      end

      it "rejects negative amount" do
        payment = build(:payment, amount: -10)
        expect(payment).not_to be_valid
        expect(payment.errors[:amount]).to be_present
      end

      it "accepts positive amount" do
        payment = build(:payment, amount: 50.00)
        expect(payment).to be_valid
      end
    end
  end

  # =============================================================================
  # ENUMS
  # =============================================================================
  describe "enums" do
    describe "status" do
      it "defines status enum values" do
        expect(Payment.statuses).to eq(
          "pending" => 0,
          "processing" => 1,
          "completed" => 2,
          "failed" => 3,
          "refunded" => 4,
          "partially_refunded" => 5
        )
      end

      it "provides status predicate methods" do
        pending_payment = create(:payment, :pending)
        expect(pending_payment.status_pending?).to be true
        expect(pending_payment.status_completed?).to be false

        completed_payment = create(:payment, :completed)
        expect(completed_payment.status_completed?).to be true
        expect(completed_payment.status_pending?).to be false
      end
    end

    describe "payment_method" do
      it "defines payment_method enum values" do
        expect(Payment.payment_methods).to eq(
          "credit_card" => 0,
          "debit_card" => 1,
          "wallet" => 2,
          "insurance" => 3
        )
      end

      it "provides payment_method predicate methods" do
        credit_payment = create(:payment, :credit_card)
        expect(credit_payment.payment_method_credit_card?).to be true
        expect(credit_payment.payment_method_debit_card?).to be false

        wallet_payment = create(:payment, :wallet)
        expect(wallet_payment.payment_method_wallet?).to be true
        expect(wallet_payment.payment_method_credit_card?).to be false
      end
    end
  end

  # =============================================================================
  # SCOPES
  # =============================================================================
  describe "scopes" do
    describe ".successful" do
      it "returns only completed payments" do
        completed1 = create(:payment, :completed)
        completed2 = create(:payment, :completed)
        create(:payment, :pending)
        create(:payment, :failed)

        expect(Payment.successful).to contain_exactly(completed1, completed2)
      end
    end

    describe ".failed" do
      it "returns only failed payments" do
        failed1 = create(:payment, :failed)
        failed2 = create(:payment, :failed)
        create(:payment, :completed)
        create(:payment, :pending)

        expect(Payment.failed).to contain_exactly(failed1, failed2)
      end
    end

    describe ".for_user" do
      it "returns payments for specific user" do
        user_id = SecureRandom.uuid
        payment1 = create(:payment, user_id: user_id)
        payment2 = create(:payment, user_id: user_id)
        create(:payment, user_id: SecureRandom.uuid)

        expect(Payment.for_user(user_id)).to contain_exactly(payment1, payment2)
      end
    end

    describe ".recent" do
      it "orders payments by created_at descending" do
        old_payment = create(:payment, created_at: 3.days.ago)
        new_payment = create(:payment, created_at: 1.day.ago)
        newest_payment = create(:payment, created_at: 1.hour.ago)

        expect(Payment.recent).to eq([ newest_payment, new_payment, old_payment ])
      end
    end

    describe ".between_dates" do
      it "returns payments within date range" do
        old_payment = create(:payment, created_at: 10.days.ago)
        in_range1 = create(:payment, created_at: 5.days.ago)
        in_range2 = create(:payment, created_at: 3.days.ago)
        recent_payment = create(:payment, created_at: 1.day.ago)

        start_date = 6.days.ago.to_date
        end_date = 2.days.ago.to_date

        result = Payment.between_dates(start_date, end_date)
        expect(result).to contain_exactly(in_range1, in_range2)
      end

      it "includes payments on start and end dates" do
        start_date = 5.days.ago.to_date
        end_date = 2.days.ago.to_date

        payment_on_start = create(:payment, created_at: start_date.beginning_of_day)
        payment_on_end = create(:payment, created_at: end_date.end_of_day - 1.minute)

        result = Payment.between_dates(start_date, end_date)
        expect(result).to include(payment_on_start, payment_on_end)
      end
    end

    describe ".for_appointment" do
      it "returns payments for specific appointment" do
        appointment_id = SecureRandom.uuid
        payment1 = create(:payment, appointment_id: appointment_id)
        payment2 = create(:payment, appointment_id: appointment_id)
        create(:payment, appointment_id: SecureRandom.uuid)

        expect(Payment.for_appointment(appointment_id)).to contain_exactly(payment1, payment2)
      end
    end

    describe ".stale_pending" do
      it "returns pending payments older than specified time" do
        old_pending = create(:payment, :pending, created_at: 2.hours.ago)
        recent_pending = create(:payment, :pending, created_at: 30.minutes.ago)
        old_completed = create(:payment, :completed, created_at: 2.hours.ago)

        result = Payment.stale_pending(1.hour)
        expect(result).to contain_exactly(old_pending)
      end

      it "uses default of 1 hour" do
        old_pending = create(:payment, :pending, created_at: 2.hours.ago)
        recent_pending = create(:payment, :pending, created_at: 30.minutes.ago)

        result = Payment.stale_pending
        expect(result).to contain_exactly(old_pending)
      end
    end
  end

  # =============================================================================
  # CALLBACKS
  # =============================================================================
  describe "callbacks" do
    describe "after_create" do
      it "does not publish events for pending status" do
        expect(EventPublisher).not_to receive(:publish)
        create(:payment, :pending)
      end

      it "publishes payment.completed event when created as completed" do
        payment = build(:payment, :completed)

        expect(EventPublisher).to receive(:publish).with(
          "payment.completed",
          hash_including(
            user_id: payment.user_id,
            appointment_id: payment.appointment_id,
            amount: payment.amount.to_f,
            currency: payment.currency
          )
        )

        payment.save!

        # Verify payment was created
        expect(payment.persisted?).to be true
      end
    end

    describe "after_update" do
      it "publishes payment.completed event when status changes to completed" do
        payment = create(:payment, :pending)

        expect(EventPublisher).to receive(:publish).with(
          "payment.completed",
          hash_including(
            payment_id: payment.id,
            user_id: payment.user_id
          )
        )

        payment.update(status: :completed, paid_at: Time.current)
      end

      it "publishes payment.failed event when status changes to failed" do
        payment = create(:payment, :pending)

        expect(EventPublisher).to receive(:publish).with(
          "payment.failed",
          hash_including(
            payment_id: payment.id,
            reason: "Card declined"
          )
        )

        payment.update(status: :failed, failure_reason: "Card declined")
      end

      it "publishes payment.refunded event when status changes to refunded" do
        payment = create(:payment, :completed)

        expect(EventPublisher).to receive(:publish).with(
          "payment.refunded",
          hash_including(
            payment_id: payment.id,
            partial: false
          )
        )

        payment.update(status: :refunded)
      end

      it "publishes payment.refunded event with partial flag for partially_refunded" do
        payment = create(:payment, :completed)

        expect(EventPublisher).to receive(:publish).with(
          "payment.refunded",
          hash_including(
            payment_id: payment.id,
            partial: true
          )
        )

        payment.update(status: :partially_refunded)
      end

      it "does not publish events when status doesn't change" do
        payment = create(:payment, :completed)

        expect(EventPublisher).not_to receive(:publish)

        payment.update(description: "Updated description")
      end

      it "logs error but doesn't fail when event publishing fails" do
        payment = create(:payment, :pending)

        allow(EventPublisher).to receive(:publish).and_raise(StandardError, "RabbitMQ connection failed")
        allow(Rails.logger).to receive(:error)

        expect {
          payment.update(status: :completed, paid_at: Time.current)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with(/Failed to publish payment event/)
      end
    end
  end

  # =============================================================================
  # INSTANCE METHODS
  # =============================================================================
  describe "#mark_as_completed!" do
    it "updates status to completed and sets charge details" do
      payment = create(:payment, :processing)
      charge_id = "ch_test123"

      freeze_time do
        payment.mark_as_completed!(charge_id: charge_id)

        expect(payment.reload).to have_attributes(
          status: "completed",
          stripe_charge_id: charge_id,
          paid_at: Time.current
        )
      end
    end

    it "raises error if update fails" do
      payment = create(:payment, :processing)

      allow(payment).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

      expect {
        payment.mark_as_completed!(charge_id: "ch_test")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#mark_as_failed!" do
    it "updates status to failed and sets failure reason" do
      payment = create(:payment, :processing)
      reason = "Insufficient funds"

      payment.mark_as_failed!(reason: reason)

      expect(payment.reload).to have_attributes(
        status: "failed",
        failure_reason: reason
      )
    end
  end

  describe "#mark_as_processing!" do
    it "updates status to processing" do
      payment = create(:payment, :pending)

      payment.mark_as_processing!

      expect(payment.reload.status).to eq("processing")
    end
  end

  describe "#mark_as_refunded!" do
    context "when partial is false" do
      it "marks payment as fully refunded" do
        payment = create(:payment, :completed)

        payment.mark_as_refunded!(partial: false)

        expect(payment.reload.status).to eq("refunded")
      end
    end

    context "when partial is true" do
      it "marks payment as partially refunded" do
        payment = create(:payment, :completed)

        payment.mark_as_refunded!(partial: true)

        expect(payment.reload.status).to eq("partially_refunded")
      end
    end

    context "when partial is not specified" do
      it "defaults to full refund" do
        payment = create(:payment, :completed)

        payment.mark_as_refunded!

        expect(payment.reload.status).to eq("refunded")
      end
    end
  end

  describe "#refundable?" do
    it "returns true for completed payment with stripe_charge_id" do
      payment = create(:payment, :completed)
      expect(payment.refundable?).to be true
    end

    it "returns false for pending payment" do
      payment = create(:payment, :pending)
      expect(payment.refundable?).to be false
    end

    it "returns false for completed payment without stripe_charge_id" do
      payment = create(:payment, status: :completed, stripe_charge_id: nil, paid_at: Time.current)
      expect(payment.refundable?).to be false
    end

    it "returns false for already refunded payment" do
      payment = create(:payment, :refunded)
      expect(payment.refundable?).to be false
    end
  end

  describe "#amount_in_cents" do
    it "converts amount to cents" do
      payment = create(:payment, amount: 50.00)
      expect(payment.amount_in_cents).to eq(5000)
    end

    it "handles decimal amounts correctly" do
      payment = create(:payment, amount: 49.99)
      expect(payment.amount_in_cents).to eq(4999)
    end

    it "rounds to nearest cent" do
      payment = create(:payment, amount: 50.555)
      expect(payment.amount_in_cents).to eq(5056) # Rounds to 50.56
    end
  end

  describe "#status_description" do
    it "returns description for pending status" do
      payment = create(:payment, :pending)
      expect(payment.status_description).to eq("Awaiting payment")
    end

    it "returns description for processing status" do
      payment = create(:payment, :processing)
      expect(payment.status_description).to eq("Payment in progress")
    end

    it "returns description for completed status" do
      payment = create(:payment, :completed)
      expect(payment.status_description).to eq("Payment successful")
    end

    it "returns description for failed status with reason" do
      payment = create(:payment, :failed, failure_reason: "Card declined")
      expect(payment.status_description).to eq("Payment failed: Card declined")
    end

    it "returns description for failed status without reason" do
      payment = create(:payment, status: :failed, failure_reason: nil)
      expect(payment.status_description).to eq("Payment failed: Unknown error")
    end

    it "returns description for refunded status" do
      payment = create(:payment, :refunded)
      expect(payment.status_description).to eq("Fully refunded")
    end

    it "returns description for partially_refunded status" do
      payment = create(:payment, :partially_refunded)
      expect(payment.status_description).to eq("Partially refunded")
    end
  end
end
