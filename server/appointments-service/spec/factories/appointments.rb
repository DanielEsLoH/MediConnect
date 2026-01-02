# frozen_string_literal: true

FactoryBot.define do
  factory :appointment do
    user_id { SecureRandom.uuid }
    doctor_id { SecureRandom.uuid }
    clinic_id { SecureRandom.uuid }
    appointment_date { 7.days.from_now.to_date }
    start_time { Time.parse("10:00:00") }
    end_time { Time.parse("10:30:00") }
    duration_minutes { 30 }
    consultation_type { "in_person" }
    status { "pending" }
    consultation_fee { 150.00 }
    reason { "Regular checkup" }
    request_id { "APT-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}" }

    trait :confirmed do
      status { "confirmed" }
      confirmed_at { Time.current }
    end

    trait :in_progress do
      status { "in_progress" }
      confirmed_at { 1.hour.ago }
    end

    trait :completed do
      status { "completed" }
      confirmed_at { 2.days.ago }
      completed_at { 2.days.ago + 30.minutes }
      notes { "Patient is doing well. No major concerns." }
    end

    trait :cancelled do
      status { "cancelled" }
      cancelled_at { 1.hour.ago }
      cancelled_by { "patient" }
      cancellation_reason { "Personal reasons" }
    end

    trait :no_show do
      status { "no_show" }
      # Use a future date by default, will be updated after creation if needed
      appointment_date { 2.days.ago.to_date }

      # Skip validation for past dates in test data
      to_create do |instance|
        instance.save(validate: false)
      end
    end

    trait :video_consultation do
      consultation_type { "video" }
    end

    trait :phone_consultation do
      consultation_type { "phone" }
    end

    trait :past_appointment do
      appointment_date { 7.days.ago.to_date }
      start_time { Time.parse("14:00:00") }
      end_time { Time.parse("14:30:00") }

      # Skip validation for past dates in test data
      to_create do |instance|
        instance.save(validate: false)
      end
    end

    trait :upcoming_appointment do
      appointment_date { 3.days.from_now.to_date }
      start_time { Time.parse("11:00:00") }
      end_time { Time.parse("11:30:00") }
      status { "confirmed" }
      confirmed_at { Time.current }
    end

    trait :with_prescription do
      prescription { "1. Amoxicillin 500mg - Take one capsule three times daily for 7 days\n2. Ibuprofen 400mg - Take as needed for pain" }
    end

    trait :expired_pending do
      status { "pending" }

      # Use after_create to update the created_at timestamp
      after(:create) do |appointment|
        appointment.update_column(:created_at, 45.minutes.ago)
      end
    end

    trait :long_appointment do
      start_time { Time.parse("09:00:00") }
      end_time { Time.parse("10:00:00") }
      duration_minutes { 60 }
    end

    trait :short_appointment do
      start_time { Time.parse("14:00:00") }
      end_time { Time.parse("14:15:00") }
      duration_minutes { 15 }
    end
  end
end