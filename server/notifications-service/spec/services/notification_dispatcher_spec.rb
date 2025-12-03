# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationDispatcher do
  let(:user_id) { SecureRandom.uuid }
  let(:notification) { create(:notification, user_id: user_id) }
  let(:dispatcher) { described_class.new(notification) }

  before do
    # Create default preferences for user
    create(:notification_preference, user_id: user_id)
  end

  describe "#dispatch" do
    context "when notification should be sent" do
      before { allow(notification).to receive(:should_send?).and_return(true) }

      context "with email delivery" do
        let(:notification) { create(:notification, :email, user_id: user_id) }
        let(:email_service) { instance_double(EmailService) }

        before do
          allow(EmailService).to receive(:new).and_return(email_service)
        end

        context "when email sends successfully" do
          before do
            allow(email_service).to receive(:send_email).and_return({ success: true })
          end

          it "marks notification as sent" do
            expect { dispatcher.dispatch }
              .to change { notification.reload.status }.from("pending").to("sent")
          end

          it "returns true" do
            expect(dispatcher.dispatch).to be true
          end
        end

        context "when email fails" do
          before do
            allow(email_service).to receive(:send_email).and_return({ success: false, error: "SMTP error" })
          end

          it "marks notification as failed" do
            expect { dispatcher.dispatch }
              .to change { notification.reload.status }.from("pending").to("failed")
          end

          it "stores error message" do
            dispatcher.dispatch
            expect(notification.reload.error_message).to eq("SMTP error")
          end

          it "returns false" do
            expect(dispatcher.dispatch).to be false
          end
        end
      end

      context "with SMS delivery" do
        let(:notification) { create(:notification, :sms, user_id: user_id) }
        let(:sms_service) { instance_double(SmsService) }

        before do
          allow(SmsService).to receive(:new).and_return(sms_service)
          allow(sms_service).to receive(:send_sms).and_return({ success: true })
        end

        it "uses SmsService" do
          expect(SmsService).to receive(:new).with(notification).and_return(sms_service)
          expect(sms_service).to receive(:send_sms)
          dispatcher.dispatch
        end
      end

      context "with push delivery" do
        let(:notification) { create(:notification, :push, user_id: user_id) }
        let(:push_service) { instance_double(PushNotificationService) }

        before do
          allow(PushNotificationService).to receive(:new).and_return(push_service)
          allow(push_service).to receive(:send_push).and_return({ success: true })
        end

        it "uses PushNotificationService" do
          expect(PushNotificationService).to receive(:new).with(notification).and_return(push_service)
          expect(push_service).to receive(:send_push)
          dispatcher.dispatch
        end
      end

      context "with in_app delivery" do
        let(:notification) { create(:notification, :in_app, user_id: user_id) }

        it "marks as sent without external service" do
          expect { dispatcher.dispatch }
            .to change { notification.reload.status }.from("pending").to("sent")
        end
      end
    end

    context "when notification should not be sent" do
      before { allow(notification).to receive(:should_send?).and_return(false) }

      it "does not dispatch notification" do
        expect(EmailService).not_to receive(:new)
        expect(dispatcher.dispatch).to be false
      end
    end

    context "when user preferences block notification" do
      let(:notification) { create(:notification, :email, :appointment_created, user_id: user_id) }

      before do
        preference = NotificationPreference.for_user(user_id)
        preference.update(email_enabled: false)
      end

      it "does not send notification" do
        expect(EmailService).not_to receive(:new)
        dispatcher.dispatch
      end

      it "marks as failed with appropriate message" do
        dispatcher.dispatch
        expect(notification.reload.status).to eq("failed")
        expect(notification.error_message).to include("User has disabled")
      end
    end

    context "when an exception occurs" do
      let(:notification) { create(:notification, :email, user_id: user_id) }

      before do
        allow(EmailService).to receive(:new).and_raise(StandardError, "Unexpected error")
      end

      it "marks notification as failed" do
        expect { dispatcher.dispatch }
          .to change { notification.reload.status }.from("pending").to("failed")
      end

      it "stores error message" do
        dispatcher.dispatch
        expect(notification.reload.error_message).to eq("Unexpected error")
      end

      it "returns false" do
        expect(dispatcher.dispatch).to be false
      end
    end
  end
end
