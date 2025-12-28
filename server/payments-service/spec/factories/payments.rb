# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    user_id { SecureRandom.uuid }
    appointment_id { SecureRandom.uuid }
    amount { 50.00 }
    currency { "USD" }
    status { :pending }
    payment_method { :credit_card }
    description { "MediConnect - Payment for appointment" }

    # Traits for different statuses
    trait :pending do
      status { :pending }
      paid_at { nil }
      stripe_payment_intent_id { nil }
      stripe_charge_id { nil }
    end

    trait :processing do
      status { :processing }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      paid_at { nil }
      stripe_charge_id { nil }
    end

    trait :completed do
      status { :completed }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      stripe_charge_id { "ch_#{SecureRandom.hex(12)}" }
      paid_at { Time.current }
    end

    trait :failed do
      status { :failed }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      failure_reason { "Card declined" }
      paid_at { nil }
      stripe_charge_id { nil }
    end

    trait :refunded do
      status { :refunded }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      stripe_charge_id { "ch_#{SecureRandom.hex(12)}" }
      paid_at { 1.day.ago }
    end

    trait :partially_refunded do
      status { :partially_refunded }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      stripe_charge_id { "ch_#{SecureRandom.hex(12)}" }
      paid_at { 1.day.ago }
    end

    # Traits for different payment methods
    trait :debit_card do
      payment_method { :debit_card }
    end

    trait :wallet do
      payment_method { :wallet }
    end

    trait :insurance do
      payment_method { :insurance }
    end

    # Traits for different amounts
    trait :low_amount do
      amount { 25.00 }
    end

    trait :high_amount do
      amount { 200.00 }
    end

    # Trait for payment without appointment
    trait :without_appointment do
      appointment_id { nil }
      description { "MediConnect - Payment" }
    end

    # Trait with unique stripe_payment_intent_id
    trait :with_unique_intent do
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(16)}" }
    end
  end
end
