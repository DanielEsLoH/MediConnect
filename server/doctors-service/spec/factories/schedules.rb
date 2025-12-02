# frozen_string_literal: true

FactoryBot.define do
  factory :schedule do
    association :doctor
    day_of_week { rand(0..6) }
    start_time { Time.zone.parse("09:00") }
    end_time { Time.zone.parse("17:00") }
    slot_duration_minutes { 30 }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :morning do
      start_time { Time.zone.parse("08:00") }
      end_time { Time.zone.parse("12:00") }
    end

    trait :afternoon do
      start_time { Time.zone.parse("13:00") }
      end_time { Time.zone.parse("17:00") }
    end
  end
end
