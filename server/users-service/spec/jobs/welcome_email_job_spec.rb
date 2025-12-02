# frozen_string_literal: true

require "rails_helper"

RSpec.describe WelcomeEmailJob, type: :job do
  describe "#perform" do
    let(:user) { create(:user) }

    it "logs the welcome email action" do
      allow(Rails.logger).to receive(:info)

      described_class.new.perform(user.id)

      expect(Rails.logger).to have_received(:info).with(/Sending welcome email to user #{user.id}/)
      expect(Rails.logger).to have_received(:info).with(/Welcome email sent to #{user.email}/)
    end

    context "when user does not exist" do
      it "does not raise error" do
        expect do
          described_class.new.perform(999_999)
        end.not_to raise_error
      end
    end

    context "when an error occurs" do
      before do
        allow(Rails.logger).to receive(:info).and_raise(StandardError, "Test error")
      end

      it "logs the error and re-raises" do
        allow(Rails.logger).to receive(:error)

        expect do
          described_class.new.perform(user.id)
        end.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).with(/Failed to send welcome email/)
      end
    end
  end
end
