# frozen_string_literal: true

FactoryBot.define do
  factory :video_session do
    association :appointment, factory: [ :appointment, :video_consultation ]
    room_name { "mediconnect-#{SecureRandom.hex(8)}" }
    session_url { "https://mediconnect.daily.co/#{room_name}" }
    provider { "daily" }
    status { "created" }

    trait :active do
      status { "active" }
      started_at { Time.current }
    end

    trait :ended do
      status { "ended" }
      started_at { 1.hour.ago }
      ended_at { 30.minutes.ago }
      duration_minutes { 30 }
    end

    trait :failed do
      status { "failed" }
    end

    trait :long_session do
      status { "ended" }
      started_at { 2.hours.ago }
      ended_at { 1.hour.ago }
      duration_minutes { 60 }
    end
  end
end
