# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfileReminderJob, type: :job do
  describe "#perform" do
    context "with incomplete profile" do
      let(:user) { create(:user, date_of_birth: nil, address: nil) }

      it "sends profile reminder" do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(user.id)

        expect(Rails.logger).to have_received(:info).with(/Sending profile reminder/)
        expect(Rails.logger).to have_received(:info).with(/Profile reminder sent/)
      end
    end

    context "with complete profile" do
      let(:user) { create(:user) }

      it "does not send profile reminder" do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(user.id)

        expect(Rails.logger).not_to have_received(:info).with(/Sending profile reminder/)
      end
    end

    context "when user does not exist" do
      it "does not raise error" do
        expect do
          described_class.new.perform(999_999)
        end.not_to raise_error
      end
    end

    context "when an error occurs" do
      let(:user) { create(:user, date_of_birth: nil) }

      before do
        allow(Rails.logger).to receive(:info).and_raise(StandardError, "Test error")
      end

      it "logs the error and re-raises" do
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.new.perform(user.id)
        end.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).with(/Failed to send profile reminder/)
      end
    end
  end
end
