# frozen_string_literal: true

# =============================================================================
# MediConnect Users Service - Seed Data
# =============================================================================
# This file creates comprehensive seed data for the Users Service.
# It is idempotent and can be run multiple times safely.
#
# Usage: rails db:seed
# =============================================================================

puts "=" * 60
puts "Seeding Users Service..."
puts "=" * 60

# =============================================================================
# SHARED UUIDs FOR CROSS-SERVICE CONSISTENCY
# =============================================================================
# These UUIDs are used across all services to maintain referential integrity
# in the microservices architecture. Each service references users by these IDs.

SHARED_USER_IDS = {
  # Admin User
  admin: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",

  # Patient Users
  patient_john_doe: "11111111-1111-1111-1111-111111111111",
  patient_sarah_johnson: "22222222-2222-2222-2222-222222222222",
  patient_michael_chen: "33333333-3333-3333-3333-333333333333",
  patient_emily_davis: "44444444-4444-4444-4444-444444444444",
  patient_david_martinez: "55555555-5555-5555-5555-555555555555",
  patient_lisa_anderson: "66666666-6666-6666-6666-666666666666",
  patient_james_wilson: "77777777-7777-7777-7777-777777777777",
  patient_patricia_taylor: "88888888-8888-8888-8888-888888888888",

  # Doctor Users (for authentication in Users Service)
  doctor_smith: "d1111111-1111-1111-1111-111111111111",
  doctor_johnson: "d2222222-2222-2222-2222-222222222222",
  doctor_williams: "d3333333-3333-3333-3333-333333333333",
  doctor_brown: "d4444444-4444-4444-4444-444444444444",
  doctor_jones: "d5555555-5555-5555-5555-555555555555"
}.freeze

# =============================================================================
# ENVIRONMENT-SPECIFIC CLEANUP
# =============================================================================
if Rails.env.development? || Rails.env.test?
  puts "Clearing existing data in #{Rails.env} environment..."
  # Clear in reverse dependency order
  MedicalRecord.destroy_all if defined?(MedicalRecord)
  Allergy.destroy_all if defined?(Allergy)
  User.destroy_all
  puts "Existing data cleared."
end

# =============================================================================
# ADMIN USER
# =============================================================================
puts "\n--- Creating Admin User ---"

admin = User.find_or_initialize_by(id: SHARED_USER_IDS[:admin])
admin.assign_attributes(
  email: "admin@mediconnect.com",
  password: "Password123!",
  first_name: "Admin",
  last_name: "User",
  phone_number: "+1-555-000-0001",
  date_of_birth: Date.new(1985, 1, 15),
  gender: "other",
  address: "100 Admin Plaza",
  city: "New York",
  state: "NY",
  zip_code: "10001",
  active: true
)
admin.save!
puts "  Created admin: #{admin.email} (ID: #{admin.id})"

# =============================================================================
# PATIENT USERS
# =============================================================================
puts "\n--- Creating Patient Users ---"

patients_data = [
  {
    id: SHARED_USER_IDS[:patient_john_doe],
    email: "john.doe@example.com",
    password: "Password123!",
    first_name: "John",
    last_name: "Doe",
    phone_number: "+1-555-101-0001",
    date_of_birth: Date.new(1990, 5, 15),
    gender: "male",
    address: "123 Main Street, Apt 4B",
    city: "New York",
    state: "NY",
    zip_code: "10001",
    emergency_contact_name: "Jane Doe",
    emergency_contact_phone: "+1-555-101-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_sarah_johnson],
    email: "sarah.johnson@example.com",
    password: "Password123!",
    first_name: "Sarah",
    last_name: "Johnson",
    phone_number: "+1-555-102-0001",
    date_of_birth: Date.new(1985, 8, 22),
    gender: "female",
    address: "456 Oak Avenue",
    city: "Brooklyn",
    state: "NY",
    zip_code: "11201",
    emergency_contact_name: "Michael Johnson",
    emergency_contact_phone: "+1-555-102-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_michael_chen],
    email: "michael.chen@example.com",
    password: "Password123!",
    first_name: "Michael",
    last_name: "Chen",
    phone_number: "+1-555-103-0001",
    date_of_birth: Date.new(1992, 3, 10),
    gender: "male",
    address: "789 Park Boulevard, Suite 12",
    city: "Manhattan",
    state: "NY",
    zip_code: "10002",
    emergency_contact_name: "Lisa Chen",
    emergency_contact_phone: "+1-555-103-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_emily_davis],
    email: "emily.davis@example.com",
    password: "Password123!",
    first_name: "Emily",
    last_name: "Davis",
    phone_number: "+1-555-104-0001",
    date_of_birth: Date.new(1988, 11, 5),
    gender: "female",
    address: "321 Elm Street",
    city: "Queens",
    state: "NY",
    zip_code: "11354",
    emergency_contact_name: "Robert Davis",
    emergency_contact_phone: "+1-555-104-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_david_martinez],
    email: "david.martinez@example.com",
    password: "Password123!",
    first_name: "David",
    last_name: "Martinez",
    phone_number: "+1-555-105-0001",
    date_of_birth: Date.new(1995, 7, 18),
    gender: "male",
    address: "654 Broadway",
    city: "Bronx",
    state: "NY",
    zip_code: "10451",
    emergency_contact_name: "Maria Martinez",
    emergency_contact_phone: "+1-555-105-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_lisa_anderson],
    email: "lisa.anderson@example.com",
    password: "Password123!",
    first_name: "Lisa",
    last_name: "Anderson",
    phone_number: "+1-555-106-0001",
    date_of_birth: Date.new(1987, 12, 30),
    gender: "female",
    address: "987 Fifth Avenue",
    city: "Staten Island",
    state: "NY",
    zip_code: "10301",
    emergency_contact_name: "James Anderson",
    emergency_contact_phone: "+1-555-106-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_james_wilson],
    email: "james.wilson@example.com",
    password: "Password123!",
    first_name: "James",
    last_name: "Wilson",
    phone_number: "+1-555-107-0001",
    date_of_birth: Date.new(1993, 4, 25),
    gender: "male",
    address: "159 Washington Street",
    city: "New York",
    state: "NY",
    zip_code: "10003",
    emergency_contact_name: "Patricia Wilson",
    emergency_contact_phone: "+1-555-107-0002"
  },
  {
    id: SHARED_USER_IDS[:patient_patricia_taylor],
    email: "patricia.taylor@example.com",
    password: "Password123!",
    first_name: "Patricia",
    last_name: "Taylor",
    phone_number: "+1-555-108-0001",
    date_of_birth: Date.new(1991, 9, 8),
    gender: "female",
    address: "753 Madison Avenue, Apt 7A",
    city: "Brooklyn",
    state: "NY",
    zip_code: "11202",
    emergency_contact_name: "Robert Taylor",
    emergency_contact_phone: "+1-555-108-0002"
  }
]

patients_data.each do |patient_attrs|
  user = User.find_or_initialize_by(id: patient_attrs[:id])
  user.assign_attributes(patient_attrs.merge(active: true))
  user.save!
  puts "  Created patient: #{user.email} (ID: #{user.id})"
end

# =============================================================================
# DOCTOR USERS (for authentication)
# =============================================================================
puts "\n--- Creating Doctor Users ---"

doctor_users_data = [
  {
    id: SHARED_USER_IDS[:doctor_smith],
    email: "dr.smith@mediconnect.com",
    password: "Password123!",
    first_name: "Robert",
    last_name: "Smith",
    phone_number: "+1-555-201-0001",
    date_of_birth: Date.new(1975, 3, 20),
    gender: "male",
    address: "500 Medical Center Drive",
    city: "New York",
    state: "NY",
    zip_code: "10016"
  },
  {
    id: SHARED_USER_IDS[:doctor_johnson],
    email: "dr.jennifer.johnson@mediconnect.com",
    password: "Password123!",
    first_name: "Jennifer",
    last_name: "Johnson",
    phone_number: "+1-555-202-0001",
    date_of_birth: Date.new(1980, 6, 15),
    gender: "female",
    address: "501 Medical Center Drive",
    city: "New York",
    state: "NY",
    zip_code: "10016"
  },
  {
    id: SHARED_USER_IDS[:doctor_williams],
    email: "dr.williams@mediconnect.com",
    password: "Password123!",
    first_name: "Michael",
    last_name: "Williams",
    phone_number: "+1-555-203-0001",
    date_of_birth: Date.new(1978, 9, 10),
    gender: "male",
    address: "502 Medical Center Drive",
    city: "Brooklyn",
    state: "NY",
    zip_code: "11201"
  },
  {
    id: SHARED_USER_IDS[:doctor_brown],
    email: "dr.brown@mediconnect.com",
    password: "Password123!",
    first_name: "Emily",
    last_name: "Brown",
    phone_number: "+1-555-204-0001",
    date_of_birth: Date.new(1982, 11, 25),
    gender: "female",
    address: "503 Medical Center Drive",
    city: "Manhattan",
    state: "NY",
    zip_code: "10002"
  },
  {
    id: SHARED_USER_IDS[:doctor_jones],
    email: "dr.jones@mediconnect.com",
    password: "Password123!",
    first_name: "David",
    last_name: "Jones",
    phone_number: "+1-555-205-0001",
    date_of_birth: Date.new(1976, 4, 8),
    gender: "male",
    address: "504 Medical Center Drive",
    city: "New York",
    state: "NY",
    zip_code: "10016"
  }
]

doctor_users_data.each do |doctor_attrs|
  user = User.find_or_initialize_by(id: doctor_attrs[:id])
  user.assign_attributes(doctor_attrs.merge(active: true))
  user.save!
  puts "  Created doctor user: #{user.email} (ID: #{user.id})"
end

# =============================================================================
# ALLERGIES (for patient users)
# =============================================================================
if defined?(Allergy)
  puts "\n--- Creating Allergies ---"

  allergies_data = [
    {
      user_id: User.find_by(email: "john.doe@example.com")&.id,
      allergen: "Penicillin",
      severity: "severe",
      reaction: "Anaphylaxis, difficulty breathing",
      diagnosed_at: Date.new(2015, 3, 10),
      active: true
    },
    {
      user_id: User.find_by(email: "john.doe@example.com")&.id,
      allergen: "Peanuts",
      severity: "moderate",
      reaction: "Hives, swelling",
      diagnosed_at: Date.new(2010, 8, 15),
      active: true
    },
    {
      user_id: User.find_by(email: "sarah.johnson@example.com")&.id,
      allergen: "Latex",
      severity: "mild",
      reaction: "Skin irritation",
      diagnosed_at: Date.new(2018, 5, 20),
      active: true
    },
    {
      user_id: User.find_by(email: "emily.davis@example.com")&.id,
      allergen: "Sulfa drugs",
      severity: "severe",
      reaction: "Severe rash, fever",
      diagnosed_at: Date.new(2012, 11, 5),
      active: true
    },
    {
      user_id: User.find_by(email: "david.martinez@example.com")&.id,
      allergen: "Shellfish",
      severity: "moderate",
      reaction: "Stomach cramps, nausea",
      diagnosed_at: Date.new(2019, 2, 14),
      active: true
    }
  ]

  allergies_data.each do |allergy_attrs|
    next unless allergy_attrs[:user_id]

    allergy = Allergy.find_or_initialize_by(
      user_id: allergy_attrs[:user_id],
      allergen: allergy_attrs[:allergen]
    )
    allergy.assign_attributes(allergy_attrs)
    allergy.save!
    puts "  Created allergy: #{allergy.allergen} for user ID #{allergy.user_id}"
  end
end

# =============================================================================
# MEDICAL RECORDS (for patient users)
# =============================================================================
if defined?(MedicalRecord)
  puts "\n--- Creating Medical Records ---"

  medical_records_data = [
    {
      user_id: User.find_by(email: "john.doe@example.com")&.id,
      title: "Annual Physical Exam 2024",
      record_type: "diagnosis",
      description: "Routine annual physical examination. All vitals normal. BMI within healthy range.",
      provider_name: "Dr. Robert Smith",
      recorded_at: 6.months.ago
    },
    {
      user_id: User.find_by(email: "john.doe@example.com")&.id,
      title: "Blood Work Results",
      record_type: "lab_result",
      description: "Complete blood count, metabolic panel. All values within normal ranges.",
      provider_name: "NYC Medical Lab",
      recorded_at: 6.months.ago
    },
    {
      user_id: User.find_by(email: "sarah.johnson@example.com")&.id,
      title: "Cardiology Consultation",
      record_type: "diagnosis",
      description: "Follow-up for minor heart palpitations. EKG normal. Recommended stress management.",
      provider_name: "Dr. Robert Smith",
      recorded_at: 3.months.ago
    },
    {
      user_id: User.find_by(email: "michael.chen@example.com")&.id,
      title: "Sports Injury Assessment",
      record_type: "diagnosis",
      description: "Right knee examination following basketball injury. Mild sprain diagnosed.",
      provider_name: "Dr. David Jones",
      recorded_at: 2.months.ago
    },
    {
      user_id: User.find_by(email: "emily.davis@example.com")&.id,
      title: "Dermatology Follow-up",
      record_type: "diagnosis",
      description: "Skin condition review. Eczema well-controlled with current treatment plan.",
      provider_name: "Dr. Jennifer Johnson",
      recorded_at: 1.month.ago
    }
  ]

  medical_records_data.each do |record_attrs|
    next unless record_attrs[:user_id]

    record = MedicalRecord.find_or_initialize_by(
      user_id: record_attrs[:user_id],
      title: record_attrs[:title]
    )
    record.assign_attributes(record_attrs)
    record.save!
    puts "  Created medical record: #{record.title}"
  end
end

# =============================================================================
# SUMMARY
# =============================================================================
puts "\n" + "=" * 60
puts "Users Service Seeding Complete!"
puts "=" * 60
puts "Summary:"
puts "  - Total Users: #{User.count}"
puts "  - Admin Users: 1"
puts "  - Patient Users: #{patients_data.length}"
puts "  - Doctor Users: #{doctor_users_data.length}"
puts "  - Allergies: #{defined?(Allergy) ? Allergy.count : 'N/A'}"
puts "  - Medical Records: #{defined?(MedicalRecord) ? MedicalRecord.count : 'N/A'}"
puts "=" * 60

# Export shared IDs for reference by other services
puts "\nShared User IDs (for cross-service reference):"
SHARED_USER_IDS.each do |key, value|
  puts "  #{key}: #{value}"
end
