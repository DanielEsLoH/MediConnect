# frozen_string_literal: true

module Internal
  # Internal API controller for doctor data
  # Called by other microservices to fetch doctor information
  #
  # @example Fetch doctor from Appointments Service
  #   response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}")
  #   doctor_name = "Dr. #{response.dig('doctor', 'first_name')} #{response.dig('doctor', 'last_name')}"
  #
  # @example Check doctor availability
  #   response = HttpClient.get(:doctors, "/internal/doctors/#{doctor_id}/availability",
  #     params: { date: "2024-01-15" }
  #   )
  #   available_slots = response.dig("available_slots")
  #
  class DoctorsController < BaseController
    # GET /internal/doctors/:id
    # Returns doctor data for internal service use
    #
    # @param id [String] Doctor UUID
    # @return [JSON] Doctor data with specialty and clinic info
    def show
      doctor = Doctor.includes(:specialty, :clinic).find(params[:id])

      render json: {
        doctor: doctor_response(doctor)
      }
    end

    # POST /internal/doctors/batch
    # Returns multiple doctors by IDs (for batch operations)
    #
    # @param doctor_ids [Array<String>] Array of doctor UUIDs
    # @return [JSON] Array of doctor data
    def batch
      doctor_ids = params.require(:doctor_ids)

      unless doctor_ids.is_a?(Array) && doctor_ids.length <= 100
        return render json: {
          error: "doctor_ids must be an array with max 100 items"
        }, status: :bad_request
      end

      doctors = Doctor.includes(:specialty, :clinic).where(id: doctor_ids)

      render json: {
        doctors: doctors.map { |doctor| doctor_response(doctor) },
        meta: {
          requested: doctor_ids.length,
          found: doctors.length
        }
      }
    end

    # GET /internal/doctors/:id/availability
    # Returns available time slots for a doctor on a given date
    #
    # @param id [String] Doctor UUID
    # @param date [String] Date in YYYY-MM-DD format
    # @return [JSON] Available slots and scheduling info
    def availability
      doctor = Doctor.includes(:schedules).find(params[:id])
      date = params[:date].present? ? Date.parse(params[:date]) : Date.today

      availability_service = AvailabilityService.new(doctor)
      slots = availability_service.available_slots(date)

      render json: {
        doctor_id: doctor.id,
        doctor_name: doctor.full_name,
        date: date.to_s,
        available_slots: slots,
        slot_duration_minutes: doctor.schedules.first&.slot_duration_minutes || 30,
        next_available_date: availability_service.next_available_date(date)
      }
    rescue ArgumentError => e
      render json: { error: "Invalid date format", details: e.message }, status: :bad_request
    end

    # GET /internal/doctors/:id/contact_info
    # Returns minimal contact information for notifications
    #
    # @param id [String] Doctor UUID
    # @return [JSON] Contact info (email, name, clinic)
    def contact_info
      doctor = Doctor.includes(:clinic).find(params[:id])

      render json: {
        doctor_id: doctor.id,
        email: doctor.email,
        phone_number: doctor.phone_number,
        first_name: doctor.first_name,
        last_name: doctor.last_name,
        full_name: doctor.full_name,
        clinic_name: doctor.clinic&.name,
        clinic_phone: doctor.clinic&.phone_number
      }
    end

    # GET /internal/doctors/:id/exists
    # Quick check if doctor exists (lightweight)
    #
    # @param id [String] Doctor UUID
    # @return [JSON] { exists: true/false, accepting_new_patients: true/false }
    def exists
      doctor = Doctor.find_by(id: params[:id])

      render json: {
        exists: doctor.present?,
        active: doctor&.active,
        accepting_new_patients: doctor&.accepting_new_patients
      }
    end

    # GET /internal/doctors/:id/validate_for_appointment
    # Validate if a doctor can accept an appointment at a given time
    #
    # @param id [String] Doctor UUID
    # @param scheduled_at [String] ISO8601 datetime
    # @return [JSON] { valid: true/false, reason: "..." }
    def validate_for_appointment
      doctor = Doctor.includes(:schedules).find(params[:id])
      scheduled_at = Time.parse(params[:scheduled_at])

      validation = validate_appointment_slot(doctor, scheduled_at)

      render json: validation
    rescue ArgumentError => e
      render json: { valid: false, reason: "Invalid datetime format: #{e.message}" }, status: :bad_request
    end

    private

    def doctor_response(doctor)
      {
        id: doctor.id,
        email: doctor.email,
        first_name: doctor.first_name,
        last_name: doctor.last_name,
        full_name: doctor.full_name,
        phone_number: doctor.phone_number,
        bio: doctor.bio,
        years_of_experience: doctor.years_of_experience,
        education: doctor.education,
        languages: doctor.languages,
        consultation_fee: doctor.consultation_fee,
        profile_picture_url: doctor.profile_picture_url,
        active: doctor.active,
        accepting_new_patients: doctor.accepting_new_patients,
        average_rating: doctor.average_rating,
        total_reviews: doctor.total_reviews,
        specialty: specialty_response(doctor.specialty),
        clinic: clinic_response(doctor.clinic),
        created_at: doctor.created_at,
        updated_at: doctor.updated_at
      }
    end

    def specialty_response(specialty)
      return nil unless specialty

      {
        id: specialty.id,
        name: specialty.name,
        description: specialty.description
      }
    end

    def clinic_response(clinic)
      return nil unless clinic

      {
        id: clinic.id,
        name: clinic.name,
        address: clinic.address,
        city: clinic.city,
        state: clinic.state,
        zip_code: clinic.zip_code,
        phone_number: clinic.phone_number
      }
    end

    def validate_appointment_slot(doctor, scheduled_at)
      unless doctor.active
        return { valid: false, reason: "Doctor is not active" }
      end

      unless doctor.accepting_new_patients
        return { valid: false, reason: "Doctor is not accepting new patients" }
      end

      # Check if doctor works on this day
      day_of_week = scheduled_at.strftime("%A").downcase
      schedule = doctor.schedules.find { |s| s.day_of_week.downcase == day_of_week }

      unless schedule
        return { valid: false, reason: "Doctor does not work on #{day_of_week.capitalize}" }
      end

      # Check if time is within schedule
      appointment_time = scheduled_at.strftime("%H:%M")
      unless appointment_time >= schedule.start_time.strftime("%H:%M") &&
             appointment_time < schedule.end_time.strftime("%H:%M")
        return {
          valid: false,
          reason: "Appointment time is outside doctor's working hours " \
                  "(#{schedule.start_time.strftime('%H:%M')} - #{schedule.end_time.strftime('%H:%M')})"
        }
      end

      { valid: true, reason: nil }
    end
  end
end
