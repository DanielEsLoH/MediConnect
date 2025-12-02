# frozen_string_literal: true

FactoryBot.define do
  factory :medical_record do
    association :user
    record_type { MedicalRecord.record_types.keys.sample }
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    recorded_at { Faker::Time.between(from: 1.year.ago, to: Time.current) }
    provider_name { Faker::Name.name }
    attachments { {} }

    trait :diagnosis do
      record_type { :diagnosis }
      title { "Diagnosed with #{Faker::Medical::Medicine.disease}" }
    end

    trait :prescription do
      record_type { :prescription }
      title { "Prescribed #{Faker::Medical::Medicine.drug_name}" }
    end

    trait :lab_result do
      record_type { :lab_result }
      title { "Lab results for #{Faker::Medical::Medicine.test_name}" }
    end

    trait :with_attachments do
      attachments do
        {
          files: [
            { url: Faker::Internet.url, filename: "report.pdf" },
            { url: Faker::Internet.url, filename: "xray.jpg" }
          ]
        }
      end
    end
  end
end
