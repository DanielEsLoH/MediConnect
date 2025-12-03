# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPreference, type: :model do
  describe "validations" do
    it { should validate_presence_of(:user_id) }
    it { should validate_uniqueness_of(:user_id) }
  end

  describe ".for_user" do
    let(:user_id) { SecureRandom.uuid }

    context "when preference exists" do
      let!(:preference) { create(:notification_preference, user_id: user_id) }

      it "returns existing preference" do
        result = described_class.for_user(user_id)
        expect(result).to eq(preference)
      end
    end

    context "when preference does not exist" do
      it "creates and returns new preference with defaults" do
        result = described_class.for_user(user_id)
        expect(result).to be_persisted
        expect(result.user_id).to eq(user_id)
        expect(result.email_enabled).to be true
        expect(result.sms_enabled).to be true
        expect(result.push_enabled).to be true
        expect(result.appointment_reminders).to be true
        expect(result.appointment_updates).to be true
        expect(result.marketing_emails).to be false
      end
    end
  end

  describe "#allows_delivery_method?" do
    let(:preference) { create(:notification_preference) }

    context "when email is enabled" do
      before { preference.update(email_enabled: true) }

      it "allows email delivery" do
        expect(preference.allows_delivery_method?(:email)).to be true
        expect(preference.allows_delivery_method?("email")).to be true
      end
    end

    context "when email is disabled" do
      before { preference.update(email_enabled: false) }

      it "does not allow email delivery" do
        expect(preference.allows_delivery_method?(:email)).to be false
      end
    end

    context "when sms is enabled" do
      before { preference.update(sms_enabled: true) }

      it "allows sms delivery" do
        expect(preference.allows_delivery_method?(:sms)).to be true
      end
    end

    context "when push is disabled" do
      before { preference.update(push_enabled: false) }

      it "does not allow push delivery" do
        expect(preference.allows_delivery_method?(:push)).to be false
      end
    end

    context "for in_app delivery" do
      it "always allows in_app delivery" do
        preference.update(email_enabled: false, sms_enabled: false, push_enabled: false)
        expect(preference.allows_delivery_method?(:in_app)).to be true
      end
    end

    context "for unknown delivery method" do
      it "returns false" do
        expect(preference.allows_delivery_method?(:unknown)).to be false
      end
    end
  end

  describe "#allows_notification_type?" do
    let(:preference) { create(:notification_preference) }

    context "when appointment_updates is enabled" do
      before { preference.update(appointment_updates: true) }

      it "allows appointment update notifications" do
        expect(preference.allows_notification_type?(:appointment_created)).to be true
        expect(preference.allows_notification_type?(:appointment_confirmed)).to be true
        expect(preference.allows_notification_type?(:appointment_cancelled)).to be true
        expect(preference.allows_notification_type?(:appointment_completed)).to be true
      end
    end

    context "when appointment_updates is disabled" do
      before { preference.update(appointment_updates: false) }

      it "does not allow appointment update notifications" do
        expect(preference.allows_notification_type?(:appointment_created)).to be false
        expect(preference.allows_notification_type?(:appointment_confirmed)).to be false
      end
    end

    context "when appointment_reminders is enabled" do
      before { preference.update(appointment_reminders: true) }

      it "allows reminder notifications" do
        expect(preference.allows_notification_type?(:appointment_reminder)).to be true
      end
    end

    context "when appointment_reminders is disabled" do
      before { preference.update(appointment_reminders: false) }

      it "does not allow reminder notifications" do
        expect(preference.allows_notification_type?(:appointment_reminder)).to be false
      end
    end

    context "for system notifications" do
      it "always allows system notifications" do
        preference.update(
          appointment_reminders: false,
          appointment_updates: false,
          marketing_emails: false
        )

        expect(preference.allows_notification_type?(:welcome_email)).to be true
        expect(preference.allows_notification_type?(:password_reset)).to be true
        expect(preference.allows_notification_type?(:payment_received)).to be true
      end
    end

    context "when marketing_emails is enabled" do
      before { preference.update(marketing_emails: true) }

      it "allows general/marketing notifications" do
        expect(preference.allows_notification_type?(:general)).to be true
      end
    end

    context "when marketing_emails is disabled" do
      before { preference.update(marketing_emails: false) }

      it "does not allow general/marketing notifications" do
        expect(preference.allows_notification_type?(:general)).to be false
      end
    end
  end

  describe "#should_send_notification?" do
    let(:preference) { create(:notification_preference) }

    context "when both notification type and delivery method are allowed" do
      before do
        preference.update(appointment_updates: true, email_enabled: true)
      end

      it "returns true" do
        expect(preference.should_send_notification?(:appointment_created, :email)).to be true
      end
    end

    context "when notification type is allowed but delivery method is not" do
      before do
        preference.update(appointment_updates: true, email_enabled: false)
      end

      it "returns false" do
        expect(preference.should_send_notification?(:appointment_created, :email)).to be false
      end
    end

    context "when delivery method is allowed but notification type is not" do
      before do
        preference.update(appointment_updates: false, email_enabled: true)
      end

      it "returns false" do
        expect(preference.should_send_notification?(:appointment_created, :email)).to be false
      end
    end

    context "when neither is allowed" do
      before do
        preference.update(appointment_updates: false, email_enabled: false)
      end

      it "returns false" do
        expect(preference.should_send_notification?(:appointment_created, :email)).to be false
      end
    end
  end
end
