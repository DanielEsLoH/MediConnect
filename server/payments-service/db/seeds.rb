# frozen_string_literal: true

# =============================================================================
# MediConnect Payments Service - Seed Data
# =============================================================================
# This file creates comprehensive seed data for the Payments Service.
# It is idempotent and can be run multiple times safely.
#
# Prerequisites:
#   - Run users-service seeds first to establish user IDs
#   - Run appointments-service seeds to establish appointment IDs
#
# Note: Stripe payment intent IDs are mock values for development/testing.
# In production, these would be real Stripe API responses.
#
# Usage: rails db:seed
# =============================================================================

puts "=" * 60
puts "Seeding Payments Service..."
puts "=" * 60

# =============================================================================
# SHARED UUIDs FOR CROSS-SERVICE CONSISTENCY
# =============================================================================

# User IDs (from Users Service)
USER_IDS = {
  john_doe: "11111111-1111-1111-1111-111111111111",
  sarah_johnson: "22222222-2222-2222-2222-222222222222",
  michael_chen: "33333333-3333-3333-3333-333333333333",
  emily_davis: "44444444-4444-4444-4444-444444444444",
  david_martinez: "55555555-5555-5555-5555-555555555555",
  lisa_anderson: "66666666-6666-6666-6666-666666666666",
  james_wilson: "77777777-7777-7777-7777-777777777777",
  patricia_taylor: "88888888-8888-8888-8888-888888888888"
}.freeze

# Appointment IDs (from Appointments Service)
APPOINTMENT_IDS = {
  # Upcoming (for pending payments)
  upcoming_1: "a0000001-0001-0001-0001-000000000001",
  upcoming_2: "a0000002-0002-0002-0002-000000000002",
  upcoming_3: "a0000003-0003-0003-0003-000000000003",
  upcoming_4: "a0000004-0004-0004-0004-000000000004",
  upcoming_5: "a0000005-0005-0005-0005-000000000005",
  upcoming_6: "a0000006-0006-0006-0006-000000000006",
  upcoming_7: "a0000007-0007-0007-0007-000000000007",

  # Past (for completed payments)
  past_1: "a1000001-1001-1001-1001-000000000001",
  past_2: "a1000002-1002-1002-1002-000000000002",
  past_3: "a1000003-1003-1003-1003-000000000003",
  past_4: "a1000004-1004-1004-1004-000000000004",
  past_5: "a1000005-1005-1005-1005-000000000005"
}.freeze

# Payment IDs (for cross-service reference)
PAYMENT_IDS = {
  completed_1: "pay00001-0001-0001-0001-000000000001",
  completed_2: "pay00002-0002-0002-0002-000000000002",
  completed_3: "pay00003-0003-0003-0003-000000000003",
  completed_4: "pay00004-0004-0004-0004-000000000004",
  completed_5: "pay00005-0005-0005-0005-000000000005",
  completed_6: "pay00006-0006-0006-0006-000000000006",
  completed_7: "pay00007-0007-0007-0007-000000000007",
  pending_1: "pay10001-1001-1001-1001-000000000001",
  pending_2: "pay10002-1002-1002-1002-000000000002",
  failed_1: "pay20001-2001-2001-2001-000000000001"
}.freeze

# =============================================================================
# ENVIRONMENT-SPECIFIC CLEANUP
# =============================================================================
if Rails.env.development? || Rails.env.test?
  puts "Clearing existing data in #{Rails.env} environment..."
  Payment.destroy_all
  puts "Existing data cleared."
end

# =============================================================================
# COMPLETED PAYMENTS (5-7 successful payments)
# =============================================================================
puts "\n--- Creating Completed Payments ---"

completed_payments_data = [
  # Payment 1: John Doe - Past appointment with Dr. Jones (General Practice)
  {
    id: PAYMENT_IDS[:completed_1],
    user_id: USER_IDS[:john_doe],
    appointment_id: APPOINTMENT_IDS[:past_1],
    amount: 100.00,
    currency: "USD",
    status: :completed,
    payment_method: :credit_card,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. David Jones - Annual physical examination",
    paid_at: 30.days.ago
  },

  # Payment 2: Sarah Johnson - Past appointment with Dr. Smith (Cardiology)
  {
    id: PAYMENT_IDS[:completed_2],
    user_id: USER_IDS[:sarah_johnson],
    appointment_id: APPOINTMENT_IDS[:past_2],
    amount: 175.00,
    currency: "USD",
    status: :completed,
    payment_method: :credit_card,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. Robert Smith - Heart palpitations follow-up",
    paid_at: 14.days.ago
  },

  # Payment 3: Emily Davis - Past video appointment with Dr. Johnson (Dermatology)
  {
    id: PAYMENT_IDS[:completed_3],
    user_id: USER_IDS[:emily_davis],
    appointment_id: APPOINTMENT_IDS[:past_3],
    amount: 150.00,
    currency: "USD",
    status: :completed,
    payment_method: :debit_card,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Video Consultation with Dr. Jennifer Johnson - Eczema treatment review",
    paid_at: 7.days.ago
  },

  # Payment 4: Michael Chen - Past appointment with Dr. Brown (Orthopedics)
  {
    id: PAYMENT_IDS[:completed_4],
    user_id: USER_IDS[:michael_chen],
    appointment_id: APPOINTMENT_IDS[:past_4],
    amount: 200.00,
    currency: "USD",
    status: :completed,
    payment_method: :credit_card,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. Emily Brown - Initial knee injury assessment",
    paid_at: 21.days.ago
  },

  # Payment 5: Patricia Taylor - Past appointment with Dr. Williams (Pediatrics)
  {
    id: PAYMENT_IDS[:completed_5],
    user_id: USER_IDS[:patricia_taylor],
    appointment_id: APPOINTMENT_IDS[:past_5],
    amount: 125.00,
    currency: "USD",
    status: :completed,
    payment_method: :wallet,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. Michael Williams - Child wellness checkup",
    paid_at: 45.days.ago
  },

  # Payment 6: John Doe - Upcoming confirmed appointment with Dr. Smith (pre-paid)
  {
    id: PAYMENT_IDS[:completed_6],
    user_id: USER_IDS[:john_doe],
    appointment_id: APPOINTMENT_IDS[:upcoming_1],
    amount: 175.00,
    currency: "USD",
    status: :completed,
    payment_method: :credit_card,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. Robert Smith - Annual cardiovascular checkup (pre-paid)",
    paid_at: 2.days.ago
  },

  # Payment 7: David Martinez - Upcoming confirmed appointment with Dr. Williams (pre-paid)
  {
    id: PAYMENT_IDS[:completed_7],
    user_id: USER_IDS[:david_martinez],
    appointment_id: APPOINTMENT_IDS[:upcoming_5],
    amount: 125.00,
    currency: "USD",
    status: :completed,
    payment_method: :debit_card,
    stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(12)}",
    stripe_charge_id: "ch_test_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. Michael Williams - Child wellness checkup (pre-paid)",
    paid_at: 3.days.ago
  }
]

completed_payments_data.each do |payment_attrs|
  payment = Payment.find_or_initialize_by(id: payment_attrs[:id])
  payment.assign_attributes(payment_attrs)
  payment.save!
  puts "  Created completed payment: #{payment.id} - $#{payment.amount} for user #{payment.user_id[0..7]}..."
end

# =============================================================================
# PENDING PAYMENTS (1-2 awaiting payment)
# =============================================================================
puts "\n--- Creating Pending Payments ---"

pending_payments_data = [
  # Pending 1: Sarah Johnson - Pending video appointment with Dr. Jones
  {
    id: PAYMENT_IDS[:pending_1],
    user_id: USER_IDS[:sarah_johnson],
    appointment_id: APPOINTMENT_IDS[:upcoming_2],
    amount: 100.00,
    currency: "USD",
    status: :pending,
    payment_method: nil,
    stripe_payment_intent_id: "pi_test_pending_#{SecureRandom.hex(12)}",
    description: "Video Consultation with Dr. David Jones - Follow-up on lab results (payment pending)"
  },

  # Pending 2: Lisa Anderson - Pending appointment with Dr. Smith
  {
    id: PAYMENT_IDS[:pending_2],
    user_id: USER_IDS[:lisa_anderson],
    appointment_id: APPOINTMENT_IDS[:upcoming_6],
    amount: 175.00,
    currency: "USD",
    status: :pending,
    payment_method: nil,
    stripe_payment_intent_id: "pi_test_pending_#{SecureRandom.hex(12)}",
    description: "Consultation with Dr. Robert Smith - Heart palpitations evaluation (payment pending)"
  }
]

pending_payments_data.each do |payment_attrs|
  payment = Payment.find_or_initialize_by(id: payment_attrs[:id])
  payment.assign_attributes(payment_attrs)
  payment.save!
  puts "  Created pending payment: #{payment.id} - $#{payment.amount} for user #{payment.user_id[0..7]}..."
end

# =============================================================================
# FAILED PAYMENT (1 failed transaction)
# =============================================================================
puts "\n--- Creating Failed Payment ---"

failed_payment_data = {
  id: PAYMENT_IDS[:failed_1],
  user_id: USER_IDS[:james_wilson],
  appointment_id: APPOINTMENT_IDS[:upcoming_7],
  amount: 100.00,
  currency: "USD",
  status: :failed,
  payment_method: :credit_card,
  stripe_payment_intent_id: "pi_test_failed_#{SecureRandom.hex(12)}",
  description: "Consultation with Dr. David Jones - Prescription refill (PAYMENT FAILED)",
  failure_reason: "Your card was declined. Please try a different payment method or contact your bank."
}

failed_payment = Payment.find_or_initialize_by(id: failed_payment_data[:id])
failed_payment.assign_attributes(failed_payment_data)
failed_payment.save!
puts "  Created failed payment: #{failed_payment.id} - $#{failed_payment.amount} (#{failed_payment.failure_reason[0..50]}...)"

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 60
puts "Payments Service Seeding Complete!"
puts "=" * 60
puts "Summary:"
puts "  - Completed Payments: #{Payment.where(status: :completed).count}"
puts "  - Pending Payments: #{Payment.where(status: :pending).count}"
puts "  - Failed Payments: #{Payment.where(status: :failed).count}"
puts "  - Total Payments: #{Payment.count}"
puts "\nPayment Statistics:"
puts "  - Total Completed Amount: $#{'%.2f' % Payment.where(status: :completed).sum(:amount)}"
puts "  - Total Pending Amount: $#{'%.2f' % Payment.where(status: :pending).sum(:amount)}"
puts "\nPayment Methods (Completed):"
Payment.where(status: :completed).group(:payment_method).count.each do |method, count|
  puts "  - #{method || 'Not specified'}: #{count}"
end
puts "=" * 60

puts "\nPayment IDs for cross-service reference:"
puts "\nCompleted:"
Payment.where(status: :completed).each do |payment|
  puts "  #{payment.id}: $#{payment.amount} - #{payment.user_id[0..7]}..."
end
puts "\nPending:"
Payment.where(status: :pending).each do |payment|
  puts "  #{payment.id}: $#{payment.amount} - #{payment.user_id[0..7]}..."
end
puts "\nFailed:"
Payment.where(status: :failed).each do |payment|
  puts "  #{payment.id}: $#{payment.amount} - #{payment.user_id[0..7]}..."
end
