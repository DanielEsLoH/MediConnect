# frozen_string_literal: true

# =============================================================================
# MediConnect Doctors Service - Seed Data
# =============================================================================
# This file creates comprehensive seed data for the Doctors Service.
# It is idempotent and can be run multiple times safely.
#
# Prerequisites: Run users-service seeds first to establish user IDs.
#
# Usage: rails db:seed
# =============================================================================

puts "=" * 60
puts "Seeding Doctors Service..."
puts "=" * 60

# =============================================================================
# SHARED UUIDs FOR CROSS-SERVICE CONSISTENCY
# =============================================================================
# These IDs must match the IDs used in the Users Service for doctors.
# Doctor profiles in this service link to user accounts via user_id.

SHARED_USER_IDS = {
  # Patient User IDs (for reviews)
  patient_john_doe: "11111111-1111-1111-1111-111111111111",
  patient_sarah_johnson: "22222222-2222-2222-2222-222222222222",
  patient_michael_chen: "33333333-3333-3333-3333-333333333333",
  patient_emily_davis: "44444444-4444-4444-4444-444444444444",
  patient_david_martinez: "55555555-5555-5555-5555-555555555555",

  # Doctor User IDs (matching Users Service)
  doctor_smith: "d1111111-1111-1111-1111-111111111111",
  doctor_johnson: "d2222222-2222-2222-2222-222222222222",
  doctor_williams: "d3333333-3333-3333-3333-333333333333",
  doctor_brown: "d4444444-4444-4444-4444-444444444444",
  doctor_jones: "d5555555-5555-5555-5555-555555555555"
}.freeze

# Shared Clinic IDs (used by Appointments Service)
SHARED_CLINIC_IDS = {
  main_medical_center: "c1111111-1111-1111-1111-111111111111",
  brooklyn_health_clinic: "c2222222-2222-2222-2222-222222222222",
  manhattan_specialty_care: "c3333333-3333-3333-3333-333333333333"
}.freeze

# Shared Doctor IDs (used by Appointments, Payments, Notifications Services)
SHARED_DOCTOR_IDS = {
  dr_smith: "doc11111-1111-1111-1111-111111111111",
  dr_johnson: "doc22222-2222-2222-2222-222222222222",
  dr_williams: "doc33333-3333-3333-3333-333333333333",
  dr_brown: "doc44444-4444-4444-4444-444444444444",
  dr_jones: "doc55555-5555-5555-5555-555555555555"
}.freeze

# =============================================================================
# ENVIRONMENT-SPECIFIC CLEANUP
# =============================================================================
if Rails.env.development? || Rails.env.test?
  puts "Clearing existing data in #{Rails.env} environment..."
  # Clear in reverse dependency order
  Review.destroy_all if defined?(Review)
  Schedule.destroy_all
  Doctor.destroy_all
  Clinic.destroy_all
  Specialty.destroy_all
  puts "Existing data cleared."
end

# =============================================================================
# SPECIALTIES
# =============================================================================
puts "\n--- Creating Specialties ---"

specialties_data = [
  {
    name: "Cardiology",
    description: "Diagnosis and treatment of heart and cardiovascular system disorders. Includes conditions like heart disease, hypertension, arrhythmias, and heart failure."
  },
  {
    name: "Dermatology",
    description: "Medical specialty focusing on skin, hair, and nail conditions. Treats acne, eczema, psoriasis, skin cancer, and cosmetic concerns."
  },
  {
    name: "Pediatrics",
    description: "Medical care for infants, children, and adolescents. Covers preventive care, developmental issues, and childhood illnesses."
  },
  {
    name: "Orthopedics",
    description: "Treatment of musculoskeletal system including bones, joints, ligaments, tendons, and muscles. Covers sports injuries, arthritis, and fractures."
  },
  {
    name: "General Practice",
    description: "Primary care medicine covering a broad range of health issues. First point of contact for patients, providing preventive care and referrals."
  }
]

specialties = {}
specialties_data.each do |specialty_attrs|
  specialty = Specialty.find_or_create_by!(name: specialty_attrs[:name]) do |s|
    s.description = specialty_attrs[:description]
  end
  specialties[specialty.name] = specialty
  puts "  Created specialty: #{specialty.name}"
end

# =============================================================================
# CLINICS
# =============================================================================
puts "\n--- Creating Clinics ---"

clinics_data = [
  {
    name: "MediConnect Main Medical Center",
    address: "500 Medical Center Drive",
    city: "New York",
    state: "NY",
    zip_code: "10016",
    phone_number: "+1-555-300-0001",
    operating_hours: {
      monday: { open: "08:00", close: "18:00" },
      tuesday: { open: "08:00", close: "18:00" },
      wednesday: { open: "08:00", close: "18:00" },
      thursday: { open: "08:00", close: "18:00" },
      friday: { open: "08:00", close: "17:00" },
      saturday: { open: "09:00", close: "13:00" },
      sunday: { open: nil, close: nil }
    },
    active: true
  },
  {
    name: "Brooklyn Health Clinic",
    address: "250 Atlantic Avenue",
    city: "Brooklyn",
    state: "NY",
    zip_code: "11201",
    phone_number: "+1-555-300-0002",
    operating_hours: {
      monday: { open: "09:00", close: "17:00" },
      tuesday: { open: "09:00", close: "17:00" },
      wednesday: { open: "09:00", close: "17:00" },
      thursday: { open: "09:00", close: "17:00" },
      friday: { open: "09:00", close: "16:00" },
      saturday: { open: nil, close: nil },
      sunday: { open: nil, close: nil }
    },
    active: true
  },
  {
    name: "Manhattan Specialty Care Center",
    address: "789 Park Avenue",
    city: "Manhattan",
    state: "NY",
    zip_code: "10002",
    phone_number: "+1-555-300-0003",
    operating_hours: {
      monday: { open: "07:00", close: "19:00" },
      tuesday: { open: "07:00", close: "19:00" },
      wednesday: { open: "07:00", close: "19:00" },
      thursday: { open: "07:00", close: "19:00" },
      friday: { open: "07:00", close: "19:00" },
      saturday: { open: "08:00", close: "14:00" },
      sunday: { open: "10:00", close: "14:00" }
    },
    active: true
  }
]

clinics = {}
clinics_data.each do |clinic_attrs|
  clinic = Clinic.find_or_create_by!(name: clinic_attrs[:name]) do |c|
    c.assign_attributes(clinic_attrs)
  end
  clinics[clinic.name] = clinic
  puts "  Created clinic: #{clinic.name} (ID: #{clinic.id})"
end

# =============================================================================
# DOCTORS
# =============================================================================
puts "\n--- Creating Doctors ---"

doctors_data = [
  {
    first_name: "Robert",
    last_name: "Smith",
    email: "dr.smith@mediconnect.com",
    phone_number: "+1-555-201-0001",
    license_number: "NY-MD-2005-001234",
    specialty_name: "Cardiology",
    clinic_name: "MediConnect Main Medical Center",
    years_of_experience: 20,
    consultation_fee: 175.00,
    bio: "Dr. Robert Smith is a board-certified cardiologist with over 20 years of experience in diagnosing and treating cardiovascular diseases. He specializes in preventive cardiology, heart failure management, and cardiac imaging. Dr. Smith has published extensively in peer-reviewed journals and is committed to patient-centered care.",
    languages: [ "English", "Spanish" ],
    accepting_new_patients: true,
    active: true
  },
  {
    first_name: "Jennifer",
    last_name: "Johnson",
    email: "dr.jennifer.johnson@mediconnect.com",
    phone_number: "+1-555-202-0001",
    license_number: "NY-MD-2010-005678",
    specialty_name: "Dermatology",
    clinic_name: "Manhattan Specialty Care Center",
    years_of_experience: 15,
    consultation_fee: 150.00,
    bio: "Dr. Jennifer Johnson is a fellowship-trained dermatologist specializing in medical and cosmetic dermatology. She has expertise in treating complex skin conditions including psoriasis, eczema, and skin cancer. Dr. Johnson is known for her compassionate approach and thorough patient education.",
    languages: [ "English", "French" ],
    accepting_new_patients: true,
    active: true
  },
  {
    first_name: "Michael",
    last_name: "Williams",
    email: "dr.williams@mediconnect.com",
    phone_number: "+1-555-203-0001",
    license_number: "NY-MD-2008-003456",
    specialty_name: "Pediatrics",
    clinic_name: "Brooklyn Health Clinic",
    years_of_experience: 17,
    consultation_fee: 125.00,
    bio: "Dr. Michael Williams is a dedicated pediatrician with 17 years of experience caring for children from infancy through adolescence. He focuses on developmental pediatrics and preventive care. Dr. Williams creates a friendly, welcoming environment to make children feel comfortable during their visits.",
    languages: [ "English", "Mandarin" ],
    accepting_new_patients: true,
    active: true
  },
  {
    first_name: "Emily",
    last_name: "Brown",
    email: "dr.brown@mediconnect.com",
    phone_number: "+1-555-204-0001",
    license_number: "NY-MD-2012-007890",
    specialty_name: "Orthopedics",
    clinic_name: "Manhattan Specialty Care Center",
    years_of_experience: 12,
    consultation_fee: 200.00,
    bio: "Dr. Emily Brown is an orthopedic surgeon specializing in sports medicine and joint reconstruction. She has treated professional athletes and recreational sports enthusiasts alike. Dr. Brown emphasizes minimally invasive techniques and comprehensive rehabilitation programs.",
    languages: [ "English" ],
    accepting_new_patients: true,
    active: true
  },
  {
    first_name: "David",
    last_name: "Jones",
    email: "dr.jones@mediconnect.com",
    phone_number: "+1-555-205-0001",
    license_number: "NY-MD-2006-002345",
    specialty_name: "General Practice",
    clinic_name: "MediConnect Main Medical Center",
    years_of_experience: 19,
    consultation_fee: 100.00,
    bio: "Dr. David Jones is a family medicine physician providing comprehensive primary care for patients of all ages. With 19 years of experience, he emphasizes preventive medicine, chronic disease management, and building long-term relationships with his patients and their families.",
    languages: [ "English", "Spanish", "Portuguese" ],
    accepting_new_patients: true,
    active: true
  }
]

doctors = {}
doctors_data.each do |doctor_attrs|
  specialty = specialties[doctor_attrs.delete(:specialty_name)]
  clinic = clinics[doctor_attrs.delete(:clinic_name)]

  doctor = Doctor.find_or_create_by!(email: doctor_attrs[:email]) do |d|
    d.assign_attributes(doctor_attrs.merge(specialty: specialty, clinic: clinic))
  end
  doctors[doctor.email] = doctor
  puts "  Created doctor: Dr. #{doctor.first_name} #{doctor.last_name} - #{specialty.name} (ID: #{doctor.id})"
end

# =============================================================================
# SCHEDULES (Doctor Availability)
# =============================================================================
puts "\n--- Creating Doctor Schedules ---"

schedules_data = [
  # Dr. Smith (Cardiology) - Main Medical Center
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :monday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :monday, start_time: "14:00", end_time: "17:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :tuesday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :tuesday, start_time: "14:00", end_time: "17:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :wednesday, start_time: "09:00", end_time: "13:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :thursday, start_time: "10:00", end_time: "16:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.smith@mediconnect.com", day_of_week: :friday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 30 },

  # Dr. Johnson (Dermatology) - Manhattan Specialty Care
  { doctor_email: "dr.jennifer.johnson@mediconnect.com", day_of_week: :monday, start_time: "08:00", end_time: "12:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jennifer.johnson@mediconnect.com", day_of_week: :monday, start_time: "13:00", end_time: "17:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jennifer.johnson@mediconnect.com", day_of_week: :tuesday, start_time: "08:00", end_time: "14:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jennifer.johnson@mediconnect.com", day_of_week: :wednesday, start_time: "10:00", end_time: "18:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jennifer.johnson@mediconnect.com", day_of_week: :thursday, start_time: "08:00", end_time: "12:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jennifer.johnson@mediconnect.com", day_of_week: :friday, start_time: "09:00", end_time: "15:00", slot_duration_minutes: 20 },

  # Dr. Williams (Pediatrics) - Brooklyn Health Clinic
  { doctor_email: "dr.williams@mediconnect.com", day_of_week: :monday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.williams@mediconnect.com", day_of_week: :monday, start_time: "13:00", end_time: "16:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.williams@mediconnect.com", day_of_week: :tuesday, start_time: "09:00", end_time: "16:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.williams@mediconnect.com", day_of_week: :wednesday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.williams@mediconnect.com", day_of_week: :thursday, start_time: "09:00", end_time: "16:00", slot_duration_minutes: 30 },
  { doctor_email: "dr.williams@mediconnect.com", day_of_week: :friday, start_time: "09:00", end_time: "14:00", slot_duration_minutes: 30 },

  # Dr. Brown (Orthopedics) - Manhattan Specialty Care
  { doctor_email: "dr.brown@mediconnect.com", day_of_week: :monday, start_time: "07:00", end_time: "12:00", slot_duration_minutes: 45 },
  { doctor_email: "dr.brown@mediconnect.com", day_of_week: :tuesday, start_time: "13:00", end_time: "18:00", slot_duration_minutes: 45 },
  { doctor_email: "dr.brown@mediconnect.com", day_of_week: :wednesday, start_time: "07:00", end_time: "12:00", slot_duration_minutes: 45 },
  { doctor_email: "dr.brown@mediconnect.com", day_of_week: :thursday, start_time: "13:00", end_time: "18:00", slot_duration_minutes: 45 },
  { doctor_email: "dr.brown@mediconnect.com", day_of_week: :friday, start_time: "08:00", end_time: "14:00", slot_duration_minutes: 45 },
  { doctor_email: "dr.brown@mediconnect.com", day_of_week: :saturday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 45 },

  # Dr. Jones (General Practice) - Main Medical Center
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :monday, start_time: "08:00", end_time: "12:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :monday, start_time: "13:00", end_time: "17:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :tuesday, start_time: "08:00", end_time: "17:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :wednesday, start_time: "08:00", end_time: "12:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :thursday, start_time: "08:00", end_time: "17:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :friday, start_time: "08:00", end_time: "15:00", slot_duration_minutes: 20 },
  { doctor_email: "dr.jones@mediconnect.com", day_of_week: :saturday, start_time: "09:00", end_time: "12:00", slot_duration_minutes: 20 }
]

schedules_data.each do |schedule_attrs|
  doctor = doctors[schedule_attrs.delete(:doctor_email)]
  next unless doctor

  start_time = Time.zone.parse(schedule_attrs[:start_time])
  end_time = Time.zone.parse(schedule_attrs[:end_time])

  schedule = Schedule.find_or_initialize_by(
    doctor: doctor,
    day_of_week: schedule_attrs[:day_of_week],
    start_time: start_time,
    end_time: end_time
  )
  schedule.assign_attributes(
    slot_duration_minutes: schedule_attrs[:slot_duration_minutes],
    active: true
  )
  schedule.save!
  puts "  Created schedule: Dr. #{doctor.last_name} - #{schedule.day_of_week.to_s.capitalize} #{schedule_attrs[:start_time]}-#{schedule_attrs[:end_time]}"
end

# =============================================================================
# REVIEWS (Patient Reviews for Doctors)
# =============================================================================
if defined?(Review)
  puts "\n--- Creating Reviews ---"

  reviews_data = [
    # Reviews for Dr. Smith (Cardiology)
    {
      doctor_email: "dr.smith@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_john_doe],
      rating: 5,
      comment: "Dr. Smith is an exceptional cardiologist. He took the time to explain my condition thoroughly and answered all my questions. Highly recommend!",
      verified: true
    },
    {
      doctor_email: "dr.smith@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_sarah_johnson],
      rating: 4,
      comment: "Very knowledgeable and professional. The wait time was a bit long, but the quality of care made up for it.",
      verified: true
    },

    # Reviews for Dr. Johnson (Dermatology)
    {
      doctor_email: "dr.jennifer.johnson@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_emily_davis],
      rating: 5,
      comment: "Dr. Johnson completely transformed my skin! After years of struggling with eczema, she found a treatment that actually works.",
      verified: true
    },
    {
      doctor_email: "dr.jennifer.johnson@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_michael_chen],
      rating: 5,
      comment: "Excellent bedside manner and very thorough examination. The office is clean and modern.",
      verified: true
    },

    # Reviews for Dr. Williams (Pediatrics)
    {
      doctor_email: "dr.williams@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_david_martinez],
      rating: 5,
      comment: "My kids love Dr. Williams! He makes every visit fun and stress-free. Great with children of all ages.",
      verified: true
    },

    # Reviews for Dr. Brown (Orthopedics)
    {
      doctor_email: "dr.brown@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_michael_chen],
      rating: 4,
      comment: "Dr. Brown helped me recover from a knee injury. Her rehabilitation plan was comprehensive and effective.",
      verified: true
    },
    {
      doctor_email: "dr.brown@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_john_doe],
      rating: 5,
      comment: "Outstanding orthopedic surgeon. She explained the procedure clearly and the recovery went exactly as she predicted.",
      verified: true
    },

    # Reviews for Dr. Jones (General Practice)
    {
      doctor_email: "dr.jones@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_sarah_johnson],
      rating: 5,
      comment: "Dr. Jones has been our family doctor for years. He truly cares about his patients and provides excellent preventive care.",
      verified: true
    },
    {
      doctor_email: "dr.jones@mediconnect.com",
      user_id: SHARED_USER_IDS[:patient_emily_davis],
      rating: 4,
      comment: "Friendly and approachable. Takes time to listen to concerns and provides practical advice.",
      verified: true
    }
  ]

  reviews_data.each do |review_attrs|
    doctor = doctors[review_attrs.delete(:doctor_email)]
    next unless doctor

    review = Review.find_or_initialize_by(
      doctor: doctor,
      user_id: review_attrs[:user_id]
    )
    review.assign_attributes(review_attrs)
    review.save!
    puts "  Created review: #{review.rating} stars for Dr. #{doctor.last_name} from user #{review.user_id}"
  end
end

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 60
puts "Doctors Service Seeding Complete!"
puts "=" * 60
puts "Summary:"
puts "  - Specialties: #{Specialty.count}"
puts "  - Clinics: #{Clinic.count}"
puts "  - Doctors: #{Doctor.count}"
puts "  - Schedules: #{Schedule.count}"
puts "  - Reviews: #{defined?(Review) ? Review.count : 'N/A'}"
puts "=" * 60

# Output doctor IDs for other services reference
puts "\nDoctor IDs for cross-service reference:"
Doctor.all.each do |doctor|
  puts "  Dr. #{doctor.last_name} (#{doctor.email}): #{doctor.id}"
end

puts "\nClinic IDs for cross-service reference:"
Clinic.all.each do |clinic|
  puts "  #{clinic.name}: #{clinic.id}"
end
