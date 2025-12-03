# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    user_id { SecureRandom.uuid }
    notification_type { :appointment_created }
    title { "Test Notification" }
    message { "This is a test notification message" }
    data do
      {
        user_email: Faker::Internet.email,
        user_name: Faker::Name.name,
        phone_number: "+1#{Faker::Number.number(digits: 10)}"
      }
    end
    delivery_method { :email }
    status { :pending }
    priority { 5 }

    trait :email do
      delivery_method { :email }
    end

    trait :sms do
      delivery_method { :sms }
    end

    trait :push do
      delivery_method { :push }
      data do
        {
          push_token: "ExponentPushToken[#{SecureRandom.hex(22)}]",
          user_name: Faker::Name.name
        }
      end
    end

    trait :in_app do
      delivery_method { :in_app }
    end

    trait :pending do
      status { :pending }
    end

    trait :sent do
      status { :sent }
      sent_at { Time.current }
    end

    trait :delivered do
      status { :delivered }
      sent_at { 5.minutes.ago }
      delivered_at { Time.current }
    end

    trait :failed do
      status { :failed }
      error_message { "Test error message" }
      retry_count { 1 }
    end

    trait :read do
      status { :read }
      sent_at { 1.hour.ago }
      delivered_at { 55.minutes.ago }
      read_at { Time.current }
    end

    trait :scheduled do
      scheduled_for { 1.day.from_now }
    end

    trait :high_priority do
      priority { 9 }
    end

    trait :low_priority do
      priority { 1 }
    end

    trait :appointment_created do
      notification_type { :appointment_created }
      title { "Appointment Scheduled" }
      message { "Your appointment has been scheduled" }
      data do
        {
          appointment_id: SecureRandom.uuid,
          user_email: Faker::Internet.email,
          user_name: Faker::Name.name,
          doctor_name: "Dr. #{Faker::Name.name}",
          scheduled_datetime: 3.days.from_now.iso8601,
          consultation_type: "video"
        }
      end
    end

    trait :appointment_reminder do
      notification_type { :appointment_reminder }
      title { "Appointment Reminder" }
      message { "You have an appointment in 24 hours" }
      scheduled_for { 2.days.from_now }
    end

    trait :appointment_cancelled do
      notification_type { :appointment_cancelled }
      title { "Appointment Cancelled" }
      message { "Your appointment has been cancelled" }
      data do
        {
          appointment_id: SecureRandom.uuid,
          user_email: Faker::Internet.email,
          cancelled_by: "doctor",
          cancellation_reason: "Doctor unavailable"
        }
      end
    end

    trait :welcome_email do
      notification_type { :welcome_email }
      title { "Welcome to MediConnect" }
      message { "Thank you for joining MediConnect" }
    end

    trait :payment_received do
      notification_type { :payment_received }
      title { "Payment Received" }
      message { "We have received your payment" }
      data do
        {
          user_email: Faker::Internet.email,
          amount: 150.00,
          transaction_id: "txn_#{SecureRandom.hex(12)}"
        }
      end
    end
  end
end
