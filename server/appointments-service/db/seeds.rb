# frozen_string_literal: true

# =============================================================================
# MediConnect Appointments Service - Seed Data
# =============================================================================
# This file creates comprehensive seed data for the Appointments Service.
# It is idempotent and can be run multiple times safely.
#
# Prerequisites:
#   - Run users-service seeds first to establish user IDs
#   - Run doctors-service seeds to establish doctor and clinic IDs
#
# Note: This service uses UUIDs for all IDs. The IDs defined here must match
# those used in other services for cross-service consistency.
#
# Usage: rails db:seed
# =============================================================================

puts "=" * 60
puts "Seeding Appointments Service..."
puts "=" * 60

# =============================================================================
# SHARED UUIDs FOR CROSS-SERVICE CONSISTENCY
# =============================================================================
# These IDs must match the IDs used across all services.

# Patient User IDs (from Users Service)
PATIENT_IDS = {
  john_doe: "11111111-1111-1111-1111-111111111111",
  sarah_johnson: "22222222-2222-2222-2222-222222222222",
  michael_chen: "33333333-3333-3333-3333-333333333333",
  emily_davis: "44444444-4444-4444-4444-444444444444",
  david_martinez: "55555555-5555-5555-5555-555555555555",
  lisa_anderson: "66666666-6666-6666-6666-666666666666",
  james_wilson: "77777777-7777-7777-7777-777777777777",
  patricia_taylor: "88888888-8888-8888-8888-888888888888"
}.freeze

# Doctor IDs (from Doctors Service - will be populated dynamically or use placeholder UUIDs)
# In production, these would come from the Doctors Service API
DOCTOR_IDS = {
  dr_smith: "d0c10001-0001-0001-0001-000000000001",
  dr_johnson: "d0c20002-0002-0002-0002-000000000002",
  dr_williams: "d0c30003-0003-0003-0003-000000000003",
  dr_brown: "d0c40004-0004-0004-0004-000000000004",
  dr_jones: "d0c50005-0005-0005-0005-000000000005"
}.freeze

# Clinic IDs (from Doctors Service)
CLINIC_IDS = {
  main_medical_center: "c1110001-0001-0001-0001-000000000001",
  brooklyn_health_clinic: "c2220002-0002-0002-0002-000000000002",
  manhattan_specialty_care: "c3330003-0003-0003-0003-000000000003"
}.freeze

# Appointment IDs (shared with Payments and Notifications Services)
APPOINTMENT_IDS = {
  # Upcoming appointments
  upcoming_1: "a0000001-0001-0001-0001-000000000001",
  upcoming_2: "a0000002-0002-0002-0002-000000000002",
  upcoming_3: "a0000003-0003-0003-0003-000000000003",
  upcoming_4: "a0000004-0004-0004-0004-000000000004",
  upcoming_5: "a0000005-0005-0005-0005-000000000005",
  upcoming_6: "a0000006-0006-0006-0006-000000000006",
  upcoming_7: "a0000007-0007-0007-0007-000000000007",

  # Past appointments
  past_1: "a1000001-1001-1001-1001-000000000001",
  past_2: "a1000002-1002-1002-1002-000000000002",
  past_3: "a1000003-1003-1003-1003-000000000003",
  past_4: "a1000004-1004-1004-1004-000000000004",
  past_5: "a1000005-1005-1005-1005-000000000005",

  # Cancelled appointments
  cancelled_1: "a2000001-2001-2001-2001-000000000001",
  cancelled_2: "a2000002-2002-2002-2002-000000000002"
}.freeze

# =============================================================================
# ENVIRONMENT-SPECIFIC CLEANUP
# =============================================================================
if Rails.env.development? || Rails.env.test?
  puts "Clearing existing data in #{Rails.env} environment..."
  VideoSession.destroy_all
  Appointment.destroy_all
  puts "Existing data cleared."
end

# =============================================================================
# HELPER METHODS
# =============================================================================

# Skip date validation for seeding past appointments
def create_appointment_without_date_validation(attrs)
  appointment = Appointment.new(attrs)
  appointment.save(validate: false)
  appointment
end

# =============================================================================
# UPCOMING APPOINTMENTS (5-7 appointments)
# =============================================================================
puts "\n--- Creating Upcoming Appointments ---"

upcoming_appointments_data = [
  # Appointment 1: John Doe with Dr. Smith (Cardiology) - Confirmed, In-person
  {
    id: APPOINTMENT_IDS[:upcoming_1],
    user_id: PATIENT_IDS[:john_doe],
    doctor_id: DOCTOR_IDS[:dr_smith],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current + 3.days,
    start_time: Time.zone.parse("10:00"),
    end_time: Time.zone.parse("10:30"),
    duration_minutes: 30,
    consultation_type: "in_person",
    status: "confirmed",
    confirmed_at: 2.days.ago,
    consultation_fee: 175.00,
    reason: "Annual cardiovascular checkup and blood pressure monitoring",
    notes: nil,
    request_id: "REQ-2024-001"
  },

  # Appointment 2: Sarah Johnson with Dr. Jones (General Practice) - Pending, Video
  {
    id: APPOINTMENT_IDS[:upcoming_2],
    user_id: PATIENT_IDS[:sarah_johnson],
    doctor_id: DOCTOR_IDS[:dr_jones],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current + 5.days,
    start_time: Time.zone.parse("14:00"),
    end_time: Time.zone.parse("14:20"),
    duration_minutes: 20,
    consultation_type: "video",
    status: "pending",
    consultation_fee: 100.00,
    reason: "Follow-up on recent lab results and medication review",
    notes: nil,
    request_id: "REQ-2024-002"
  },

  # Appointment 3: Michael Chen with Dr. Brown (Orthopedics) - Confirmed, In-person
  {
    id: APPOINTMENT_IDS[:upcoming_3],
    user_id: PATIENT_IDS[:michael_chen],
    doctor_id: DOCTOR_IDS[:dr_brown],
    clinic_id: CLINIC_IDS[:manhattan_specialty_care],
    appointment_date: Date.current + 7.days,
    start_time: Time.zone.parse("09:00"),
    end_time: Time.zone.parse("09:45"),
    duration_minutes: 45,
    consultation_type: "in_person",
    status: "confirmed",
    confirmed_at: 1.day.ago,
    consultation_fee: 200.00,
    reason: "Knee injury follow-up and physical therapy assessment",
    notes: nil,
    request_id: "REQ-2024-003"
  },

  # Appointment 4: Emily Davis with Dr. Johnson (Dermatology) - Pending, Video
  {
    id: APPOINTMENT_IDS[:upcoming_4],
    user_id: PATIENT_IDS[:emily_davis],
    doctor_id: DOCTOR_IDS[:dr_johnson],
    clinic_id: CLINIC_IDS[:manhattan_specialty_care],
    appointment_date: Date.current + 2.days,
    start_time: Time.zone.parse("11:00"),
    end_time: Time.zone.parse("11:20"),
    duration_minutes: 20,
    consultation_type: "video",
    status: "pending",
    consultation_fee: 150.00,
    reason: "Eczema flare-up consultation",
    notes: nil,
    request_id: "REQ-2024-004"
  },

  # Appointment 5: David Martinez with Dr. Williams (Pediatrics) - Confirmed, In-person
  {
    id: APPOINTMENT_IDS[:upcoming_5],
    user_id: PATIENT_IDS[:david_martinez],
    doctor_id: DOCTOR_IDS[:dr_williams],
    clinic_id: CLINIC_IDS[:brooklyn_health_clinic],
    appointment_date: Date.current + 4.days,
    start_time: Time.zone.parse("15:00"),
    end_time: Time.zone.parse("15:30"),
    duration_minutes: 30,
    consultation_type: "in_person",
    status: "confirmed",
    confirmed_at: 3.days.ago,
    consultation_fee: 125.00,
    reason: "Child wellness checkup and vaccinations",
    notes: nil,
    request_id: "REQ-2024-005"
  },

  # Appointment 6: Lisa Anderson with Dr. Smith (Cardiology) - Pending, In-person
  {
    id: APPOINTMENT_IDS[:upcoming_6],
    user_id: PATIENT_IDS[:lisa_anderson],
    doctor_id: DOCTOR_IDS[:dr_smith],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current + 10.days,
    start_time: Time.zone.parse("11:00"),
    end_time: Time.zone.parse("11:30"),
    duration_minutes: 30,
    consultation_type: "in_person",
    status: "pending",
    consultation_fee: 175.00,
    reason: "Heart palpitations evaluation",
    notes: nil,
    request_id: "REQ-2024-006"
  },

  # Appointment 7: James Wilson with Dr. Jones (General Practice) - Confirmed, Phone
  {
    id: APPOINTMENT_IDS[:upcoming_7],
    user_id: PATIENT_IDS[:james_wilson],
    doctor_id: DOCTOR_IDS[:dr_jones],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current + 1.day,
    start_time: Time.zone.parse("16:00"),
    end_time: Time.zone.parse("16:20"),
    duration_minutes: 20,
    consultation_type: "phone",
    status: "confirmed",
    confirmed_at: 1.hour.ago,
    consultation_fee: 100.00,
    reason: "Prescription refill and quick check-in",
    notes: nil,
    request_id: "REQ-2024-007"
  }
]

upcoming_appointments = {}
upcoming_appointments_data.each do |appt_attrs|
  appointment = Appointment.find_or_initialize_by(id: appt_attrs[:id])
  appointment.assign_attributes(appt_attrs)
  appointment.save!
  upcoming_appointments[appt_attrs[:id]] = appointment
  puts "  Created upcoming appointment: #{appointment.id} - #{appointment.status} on #{appointment.appointment_date}"
end

# =============================================================================
# PAST APPOINTMENTS (3-5 completed appointments)
# =============================================================================
puts "\n--- Creating Past Appointments ---"

past_appointments_data = [
  # Past 1: John Doe with Dr. Jones - Completed
  {
    id: APPOINTMENT_IDS[:past_1],
    user_id: PATIENT_IDS[:john_doe],
    doctor_id: DOCTOR_IDS[:dr_jones],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current - 30.days,
    start_time: Time.zone.parse("09:00"),
    end_time: Time.zone.parse("09:20"),
    duration_minutes: 20,
    consultation_type: "in_person",
    status: "completed",
    confirmed_at: 32.days.ago,
    completed_at: 30.days.ago + 9.hours + 25.minutes,
    consultation_fee: 100.00,
    reason: "Annual physical examination",
    notes: "Patient in good health. Blood pressure normal. Recommended continuing current exercise routine.",
    prescription: "No medications prescribed. Continue daily multivitamin.",
    request_id: "REQ-2024-P001"
  },

  # Past 2: Sarah Johnson with Dr. Smith - Completed
  {
    id: APPOINTMENT_IDS[:past_2],
    user_id: PATIENT_IDS[:sarah_johnson],
    doctor_id: DOCTOR_IDS[:dr_smith],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current - 14.days,
    start_time: Time.zone.parse("14:00"),
    end_time: Time.zone.parse("14:30"),
    duration_minutes: 30,
    consultation_type: "in_person",
    status: "completed",
    confirmed_at: 16.days.ago,
    completed_at: 14.days.ago + 14.hours + 35.minutes,
    consultation_fee: 175.00,
    reason: "Heart palpitations follow-up",
    notes: "EKG results normal. Palpitations likely stress-related. Recommended stress management techniques and follow-up in 3 months.",
    prescription: nil,
    request_id: "REQ-2024-P002"
  },

  # Past 3: Emily Davis with Dr. Johnson - Completed (Video)
  {
    id: APPOINTMENT_IDS[:past_3],
    user_id: PATIENT_IDS[:emily_davis],
    doctor_id: DOCTOR_IDS[:dr_johnson],
    clinic_id: CLINIC_IDS[:manhattan_specialty_care],
    appointment_date: Date.current - 7.days,
    start_time: Time.zone.parse("10:00"),
    end_time: Time.zone.parse("10:20"),
    duration_minutes: 20,
    consultation_type: "video",
    status: "completed",
    confirmed_at: 9.days.ago,
    completed_at: 7.days.ago + 10.hours + 22.minutes,
    consultation_fee: 150.00,
    reason: "Eczema treatment review",
    notes: "Skin condition has improved significantly. Patient responding well to topical treatment. Continue current regimen.",
    prescription: "Hydrocortisone cream 1% - Apply twice daily to affected areas for 2 more weeks.",
    request_id: "REQ-2024-P003"
  },

  # Past 4: Michael Chen with Dr. Brown - Completed
  {
    id: APPOINTMENT_IDS[:past_4],
    user_id: PATIENT_IDS[:michael_chen],
    doctor_id: DOCTOR_IDS[:dr_brown],
    clinic_id: CLINIC_IDS[:manhattan_specialty_care],
    appointment_date: Date.current - 21.days,
    start_time: Time.zone.parse("08:00"),
    end_time: Time.zone.parse("08:45"),
    duration_minutes: 45,
    consultation_type: "in_person",
    status: "completed",
    confirmed_at: 23.days.ago,
    completed_at: 21.days.ago + 8.hours + 50.minutes,
    consultation_fee: 200.00,
    reason: "Initial knee injury assessment",
    notes: "MRI shows mild ACL sprain. Recommended physical therapy 2x per week. Avoid high-impact activities for 6 weeks.",
    prescription: "Ibuprofen 400mg - Take as needed for pain, maximum 3 times daily.",
    request_id: "REQ-2024-P004"
  },

  # Past 5: Patricia Taylor with Dr. Williams - Completed
  {
    id: APPOINTMENT_IDS[:past_5],
    user_id: PATIENT_IDS[:patricia_taylor],
    doctor_id: DOCTOR_IDS[:dr_williams],
    clinic_id: CLINIC_IDS[:brooklyn_health_clinic],
    appointment_date: Date.current - 45.days,
    start_time: Time.zone.parse("11:00"),
    end_time: Time.zone.parse("11:30"),
    duration_minutes: 30,
    consultation_type: "in_person",
    status: "completed",
    confirmed_at: 47.days.ago,
    completed_at: 45.days.ago + 11.hours + 35.minutes,
    consultation_fee: 125.00,
    reason: "Child wellness checkup",
    notes: "Child development on track. All vaccinations up to date. No concerns noted.",
    prescription: nil,
    request_id: "REQ-2024-P005"
  }
]

past_appointments = {}
past_appointments_data.each do |appt_attrs|
  # Use find_or_initialize and skip validation for past dates
  appointment = Appointment.find_by(id: appt_attrs[:id])
  if appointment.nil?
    appointment = create_appointment_without_date_validation(appt_attrs)
  else
    appointment.assign_attributes(appt_attrs)
    appointment.save(validate: false)
  end
  past_appointments[appt_attrs[:id]] = appointment
  puts "  Created past appointment: #{appointment.id} - #{appointment.status} on #{appointment.appointment_date}"
end

# =============================================================================
# CANCELLED APPOINTMENTS (1-2 appointments)
# =============================================================================
puts "\n--- Creating Cancelled Appointments ---"

cancelled_appointments_data = [
  # Cancelled 1: James Wilson cancelled by patient
  {
    id: APPOINTMENT_IDS[:cancelled_1],
    user_id: PATIENT_IDS[:james_wilson],
    doctor_id: DOCTOR_IDS[:dr_smith],
    clinic_id: CLINIC_IDS[:main_medical_center],
    appointment_date: Date.current - 5.days,
    start_time: Time.zone.parse("10:00"),
    end_time: Time.zone.parse("10:30"),
    duration_minutes: 30,
    consultation_type: "in_person",
    status: "cancelled",
    confirmed_at: 7.days.ago,
    cancelled_at: 6.days.ago,
    cancelled_by: "patient",
    cancellation_reason: "Work conflict - unable to get time off. Will reschedule.",
    consultation_fee: 175.00,
    reason: "Cardiology consultation for chest discomfort",
    request_id: "REQ-2024-C001"
  },

  # Cancelled 2: Lisa Anderson cancelled by doctor
  {
    id: APPOINTMENT_IDS[:cancelled_2],
    user_id: PATIENT_IDS[:lisa_anderson],
    doctor_id: DOCTOR_IDS[:dr_johnson],
    clinic_id: CLINIC_IDS[:manhattan_specialty_care],
    appointment_date: Date.current - 3.days,
    start_time: Time.zone.parse("15:00"),
    end_time: Time.zone.parse("15:20"),
    duration_minutes: 20,
    consultation_type: "video",
    status: "cancelled",
    confirmed_at: 5.days.ago,
    cancelled_at: 4.days.ago,
    cancelled_by: "doctor",
    cancellation_reason: "Doctor unavailable due to emergency. Patient offered alternative appointment.",
    consultation_fee: 150.00,
    reason: "Skin rash evaluation",
    request_id: "REQ-2024-C002"
  }
]

cancelled_appointments = {}
cancelled_appointments_data.each do |appt_attrs|
  appointment = Appointment.find_by(id: appt_attrs[:id])
  if appointment.nil?
    appointment = create_appointment_without_date_validation(appt_attrs)
  else
    appointment.assign_attributes(appt_attrs)
    appointment.save(validate: false)
  end
  cancelled_appointments[appt_attrs[:id]] = appointment
  puts "  Created cancelled appointment: #{appointment.id} - cancelled by #{appointment.cancelled_by}"
end

# =============================================================================
# VIDEO SESSIONS (for video consultation appointments)
# =============================================================================
puts "\n--- Creating Video Sessions ---"

# Video sessions for video type appointments
video_appointments = [
  # Upcoming video appointments
  upcoming_appointments[APPOINTMENT_IDS[:upcoming_2]],
  upcoming_appointments[APPOINTMENT_IDS[:upcoming_4]],
  # Past video appointments
  past_appointments[APPOINTMENT_IDS[:past_3]]
].compact

video_appointments.each do |appointment|
  next unless appointment&.video? || appointment&.consultation_type == "video"

  session_status = if appointment.completed?
                     "ended"
  elsif appointment.appointment_date < Date.current
                     "ended"
  else
                     "created"
  end

  video_session = VideoSession.find_or_initialize_by(appointment_id: appointment.id)
  video_session.assign_attributes(
    room_name: "mediconnect-#{appointment.id[0..7]}-#{SecureRandom.hex(4)}",
    session_url: "ws://localhost:7880/mediconnect-#{appointment.id[0..7]}",
    provider: "livekit",
    status: session_status,
    started_at: appointment.completed? ? appointment.appointment_date.to_time + appointment.start_time.seconds_since_midnight.seconds : nil,
    ended_at: appointment.completed? ? appointment.appointment_date.to_time + appointment.end_time.seconds_since_midnight.seconds : nil,
    duration_minutes: appointment.completed? ? appointment.duration_minutes : nil
  )
  video_session.save!
  puts "  Created video session: #{video_session.room_name} (#{video_session.status})"
end

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 60
puts "Appointments Service Seeding Complete!"
puts "=" * 60
puts "Summary:"
puts "  - Upcoming Appointments: #{upcoming_appointments_data.length}"
puts "    - Confirmed: #{upcoming_appointments_data.count { |a| a[:status] == 'confirmed' }}"
puts "    - Pending: #{upcoming_appointments_data.count { |a| a[:status] == 'pending' }}"
puts "  - Past Appointments (Completed): #{past_appointments_data.length}"
puts "  - Cancelled Appointments: #{cancelled_appointments_data.length}"
puts "  - Video Sessions: #{VideoSession.count}"
puts "  - Total Appointments: #{Appointment.count}"
puts "=" * 60

puts "\nAppointment IDs for cross-service reference:"
puts "\nUpcoming:"
upcoming_appointments.each do |id, appt|
  puts "  #{id}: #{appt.status} - #{appt.appointment_date}"
end
puts "\nPast:"
past_appointments.each do |id, appt|
  puts "  #{id}: #{appt.status} - #{appt.appointment_date}"
end
puts "\nCancelled:"
cancelled_appointments.each do |id, appt|
  puts "  #{id}: #{appt.status} - cancelled by #{appt.cancelled_by}"
end
