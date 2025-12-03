# frozen_string_literal: true

FactoryBot.define do
  factory :notification_preference do
    user_id { SecureRandom.uuid }
    email_enabled { true }
    sms_enabled { true }
    push_enabled { true }
    appointment_reminders { true }
    appointment_updates { true }
    marketing_emails { false }

    trait :all_disabled do
      email_enabled { false }
      sms_enabled { false }
      push_enabled { false }
      appointment_reminders { false }
      appointment_updates { false }
      marketing_emails { false }
    end

    trait :email_only do
      email_enabled { true }
      sms_enabled { false }
      push_enabled { false }
    end

    trait :no_marketing do
      marketing_emails { false }
    end

    trait :no_reminders do
      appointment_reminders { false }
    end
  end
end
