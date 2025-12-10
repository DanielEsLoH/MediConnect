# frozen_string_literal: true

# =============================================================================
# MediConnect Notifications Service - Seed Data
# =============================================================================
# This file creates comprehensive seed data for the Notifications Service.
# It is idempotent and can be run multiple times safely.
#
# Prerequisites:
#   - Run users-service seeds first to establish user IDs
#   - Run appointments-service seeds to establish appointment IDs
#
# Usage: rails db:seed
# =============================================================================

puts "=" * 60
puts "Seeding Notifications Service..."
puts "=" * 60

# =============================================================================
# SHARED UUIDs FOR CROSS-SERVICE CONSISTENCY
# =============================================================================

# User IDs (from Users Service)
USER_IDS = {
  admin: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
  john_doe: "11111111-1111-1111-1111-111111111111",
  sarah_johnson: "22222222-2222-2222-2222-222222222222",
  michael_chen: "33333333-3333-3333-3333-333333333333",
  emily_davis: "44444444-4444-4444-4444-444444444444",
  david_martinez: "55555555-5555-5555-5555-555555555555",
  lisa_anderson: "66666666-6666-6666-6666-666666666666",
  james_wilson: "77777777-7777-7777-7777-777777777777",
  patricia_taylor: "88888888-8888-8888-8888-888888888888",
  doctor_smith: "d1111111-1111-1111-1111-111111111111",
  doctor_johnson: "d2222222-2222-2222-2222-222222222222",
  doctor_williams: "d3333333-3333-3333-3333-333333333333",
  doctor_brown: "d4444444-4444-4444-4444-444444444444",
  doctor_jones: "d5555555-5555-5555-5555-555555555555"
}.freeze

# Appointment IDs (from Appointments Service)
APPOINTMENT_IDS = {
  upcoming_1: "a0000001-0001-0001-0001-000000000001",
  upcoming_2: "a0000002-0002-0002-0002-000000000002",
  upcoming_3: "a0000003-0003-0003-0003-000000000003",
  upcoming_5: "a0000005-0005-0005-0005-000000000005",
  past_1: "a1000001-1001-1001-1001-000000000001",
  past_2: "a1000002-1002-1002-1002-000000000002",
  past_3: "a1000003-1003-1003-1003-000000000003"
}.freeze

# =============================================================================
# ENVIRONMENT-SPECIFIC CLEANUP
# =============================================================================
if Rails.env.development? || Rails.env.test?
  puts "Clearing existing data in #{Rails.env} environment..."
  Notification.destroy_all
  NotificationPreference.destroy_all
  puts "Existing data cleared."
end

# =============================================================================
# NOTIFICATION PREFERENCES (for all users)
# =============================================================================
puts "\n--- Creating Notification Preferences ---"

preferences_data = [
  # Admin - receives all notifications
  {
    user_id: USER_IDS[:admin],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Patient: John Doe - all enabled
  {
    user_id: USER_IDS[:john_doe],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: true
  },

  # Patient: Sarah Johnson - email only
  {
    user_id: USER_IDS[:sarah_johnson],
    email_enabled: true,
    sms_enabled: false,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Patient: Michael Chen - all enabled
  {
    user_id: USER_IDS[:michael_chen],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: true
  },

  # Patient: Emily Davis - minimal notifications
  {
    user_id: USER_IDS[:emily_davis],
    email_enabled: true,
    sms_enabled: false,
    push_enabled: false,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Patient: David Martinez - all enabled
  {
    user_id: USER_IDS[:david_martinez],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: true
  },

  # Patient: Lisa Anderson - push and email
  {
    user_id: USER_IDS[:lisa_anderson],
    email_enabled: true,
    sms_enabled: false,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Patient: James Wilson - all enabled
  {
    user_id: USER_IDS[:james_wilson],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Patient: Patricia Taylor - email and push
  {
    user_id: USER_IDS[:patricia_taylor],
    email_enabled: true,
    sms_enabled: false,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: true
  },

  # Doctor: Dr. Smith
  {
    user_id: USER_IDS[:doctor_smith],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Doctor: Dr. Johnson
  {
    user_id: USER_IDS[:doctor_johnson],
    email_enabled: true,
    sms_enabled: false,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Doctor: Dr. Williams
  {
    user_id: USER_IDS[:doctor_williams],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Doctor: Dr. Brown
  {
    user_id: USER_IDS[:doctor_brown],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  },

  # Doctor: Dr. Jones
  {
    user_id: USER_IDS[:doctor_jones],
    email_enabled: true,
    sms_enabled: true,
    push_enabled: true,
    appointment_reminders: true,
    appointment_updates: true,
    marketing_emails: false
  }
]

preferences_data.each do |pref_attrs|
  preference = NotificationPreference.find_or_initialize_by(user_id: pref_attrs[:user_id])
  preference.assign_attributes(pref_attrs)
  preference.save!
  puts "  Created preferences for user: #{pref_attrs[:user_id]}"
end

# =============================================================================
# NOTIFICATIONS (5-10 sample notifications)
# =============================================================================
puts "\n--- Creating Notifications ---"

notifications_data = [
  # 1. Appointment Created - Sent, Read (John Doe)
  {
    user_id: USER_IDS[:john_doe],
    notification_type: "appointment_created",
    title: "Appointment Scheduled",
    message: "Your appointment with Dr. Robert Smith has been scheduled for #{(Date.current + 3.days).strftime('%B %d, %Y')} at 10:00 AM. Please arrive 15 minutes early.",
    delivery_method: "email",
    status: "read",
    priority: 5,
    sent_at: 2.days.ago,
    delivered_at: 2.days.ago + 5.seconds,
    read_at: 2.days.ago + 1.hour,
    data: {
      appointment_id: APPOINTMENT_IDS[:upcoming_1],
      doctor_name: "Dr. Robert Smith",
      appointment_date: (Date.current + 3.days).iso8601,
      appointment_time: "10:00 AM"
    }
  },

  # 2. Appointment Confirmed - Sent, Unread (Sarah Johnson)
  {
    user_id: USER_IDS[:sarah_johnson],
    notification_type: "appointment_confirmed",
    title: "Appointment Confirmed",
    message: "Great news! Your video consultation with Dr. David Jones has been confirmed for #{(Date.current + 5.days).strftime('%B %d, %Y')} at 2:00 PM. A video link will be sent before the appointment.",
    delivery_method: "email",
    status: "delivered",
    priority: 5,
    sent_at: 1.day.ago,
    delivered_at: 1.day.ago + 3.seconds,
    data: {
      appointment_id: APPOINTMENT_IDS[:upcoming_2],
      doctor_name: "Dr. David Jones",
      appointment_date: (Date.current + 5.days).iso8601,
      consultation_type: "video"
    }
  },

  # 3. Appointment Reminder - Pending (Michael Chen - scheduled for tomorrow)
  {
    user_id: USER_IDS[:michael_chen],
    notification_type: "appointment_reminder",
    title: "Appointment Reminder",
    message: "Reminder: You have an appointment with Dr. Emily Brown tomorrow at 9:00 AM at Manhattan Specialty Care Center. Please remember to bring your insurance card.",
    delivery_method: "push",
    status: "pending",
    priority: 7,
    scheduled_for: Time.current + 12.hours,
    data: {
      appointment_id: APPOINTMENT_IDS[:upcoming_3],
      doctor_name: "Dr. Emily Brown",
      clinic_name: "Manhattan Specialty Care Center"
    }
  },

  # 4. Payment Received - Sent, Read (John Doe - for past appointment)
  {
    user_id: USER_IDS[:john_doe],
    notification_type: "payment_received",
    title: "Payment Confirmation",
    message: "Thank you! Your payment of $100.00 for your appointment with Dr. David Jones has been received. A receipt has been sent to your email.",
    delivery_method: "email",
    status: "read",
    priority: 4,
    sent_at: 30.days.ago,
    delivered_at: 30.days.ago + 2.seconds,
    read_at: 30.days.ago + 30.minutes,
    data: {
      appointment_id: APPOINTMENT_IDS[:past_1],
      amount: 100.00,
      currency: "USD",
      payment_id: "pay_test_001"
    }
  },

  # 5. Appointment Completed - Sent, Unread (Sarah Johnson)
  {
    user_id: USER_IDS[:sarah_johnson],
    notification_type: "appointment_completed",
    title: "Appointment Summary Available",
    message: "Your appointment with Dr. Robert Smith has been completed. View your appointment summary and any prescriptions in the app.",
    delivery_method: "in_app",
    status: "delivered",
    priority: 3,
    sent_at: 14.days.ago,
    delivered_at: 14.days.ago,
    data: {
      appointment_id: APPOINTMENT_IDS[:past_2],
      doctor_name: "Dr. Robert Smith"
    }
  },

  # 6. Appointment Cancelled - Sent, Read (James Wilson)
  {
    user_id: USER_IDS[:james_wilson],
    notification_type: "appointment_cancelled",
    title: "Appointment Cancelled",
    message: "Your appointment with Dr. Robert Smith scheduled for #{(Date.current - 5.days).strftime('%B %d, %Y')} has been cancelled as requested. Need to reschedule? Book a new appointment in the app.",
    delivery_method: "email",
    status: "read",
    priority: 6,
    sent_at: 6.days.ago,
    delivered_at: 6.days.ago + 4.seconds,
    read_at: 6.days.ago + 2.hours,
    data: {
      cancelled_by: "patient",
      reason: "Work conflict"
    }
  },

  # 7. Welcome Email - Sent, Read (New patient)
  {
    user_id: USER_IDS[:patricia_taylor],
    notification_type: "welcome_email",
    title: "Welcome to MediConnect!",
    message: "Welcome to MediConnect! Your account has been created successfully. Start by booking your first appointment with one of our qualified healthcare providers.",
    delivery_method: "email",
    status: "read",
    priority: 2,
    sent_at: 60.days.ago,
    delivered_at: 60.days.ago + 1.second,
    read_at: 60.days.ago + 10.minutes,
    data: {
      account_created_at: 60.days.ago.iso8601
    }
  },

  # 8. Appointment Reminder SMS - Sent (David Martinez)
  {
    user_id: USER_IDS[:david_martinez],
    notification_type: "appointment_reminder",
    title: "Upcoming Appointment",
    message: "MediConnect: Reminder - Appointment with Dr. Williams on #{(Date.current + 4.days).strftime('%b %d')} at 3:00 PM. Reply HELP for assistance.",
    delivery_method: "sms",
    status: "sent",
    priority: 7,
    sent_at: 1.hour.ago,
    data: {
      appointment_id: APPOINTMENT_IDS[:upcoming_5],
      doctor_name: "Dr. Michael Williams"
    }
  },

  # 9. General Notification - Failed with retry (Emily Davis)
  {
    user_id: USER_IDS[:emily_davis],
    notification_type: "general",
    title: "New Feature Available",
    message: "Exciting news! Video consultations are now available. Book a virtual appointment from the comfort of your home.",
    delivery_method: "push",
    status: "failed",
    priority: 1,
    retry_count: 2,
    error_message: "Push notification token expired. User needs to re-enable push notifications.",
    data: {
      feature: "video_consultations",
      cta_url: "/appointments/new?type=video"
    }
  },

  # 10. Payment Received Push - Delivered (Emily Davis - recent video consultation)
  {
    user_id: USER_IDS[:emily_davis],
    notification_type: "payment_received",
    title: "Payment Successful",
    message: "Your payment of $150.00 has been processed successfully for your dermatology consultation.",
    delivery_method: "email",
    status: "delivered",
    priority: 4,
    sent_at: 7.days.ago,
    delivered_at: 7.days.ago + 3.seconds,
    data: {
      appointment_id: APPOINTMENT_IDS[:past_3],
      amount: 150.00,
      currency: "USD"
    }
  }
]

notifications_data.each do |notification_attrs|
  # Generate a unique identifier for finding duplicates
  notification = Notification.find_or_initialize_by(
    user_id: notification_attrs[:user_id],
    notification_type: notification_attrs[:notification_type],
    title: notification_attrs[:title],
    created_at: notification_attrs[:sent_at] || Time.current
  )

  notification.assign_attributes(notification_attrs.except(:created_at))
  notification.save!

  status_display = notification.read_at ? "read" : (notification.delivered_at ? "delivered" : notification.status)
  puts "  Created notification: #{notification.notification_type} for #{notification.user_id[0..7]}... (#{status_display})"
end

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 60
puts "Notifications Service Seeding Complete!"
puts "=" * 60
puts "Summary:"
puts "  - Notification Preferences: #{NotificationPreference.count}"
puts "  - Total Notifications: #{Notification.count}"
puts "    - Read: #{Notification.where.not(read_at: nil).count}"
puts "    - Unread: #{Notification.where(read_at: nil).where.not(status: 'failed').count}"
puts "    - Pending: #{Notification.where(status: 'pending').count}"
puts "    - Failed: #{Notification.where(status: 'failed').count}"
puts "  - By Type:"
Notification.group(:notification_type).count.each do |type, count|
  puts "    - #{type}: #{count}"
end
puts "  - By Delivery Method:"
Notification.group(:delivery_method).count.each do |method, count|
  puts "    - #{method}: #{count}"
end
puts "=" * 60
