# frozen_string_literal: true

class AppointmentBookingService
  attr_reader :errors

  USERS_SERVICE_URL = ENV.fetch("USERS_SERVICE_URL", "http://localhost:3001")
  DOCTORS_SERVICE_URL = ENV.fetch("DOCTORS_SERVICE_URL", "http://localhost:3002")

  def initialize(params)
    @params = params
    @errors = []
  end

  def call
    validate_params
    return failure_result if @errors.any?

    validate_user_exists
    return failure_result if @errors.any?

    validate_doctor_and_clinic
    return failure_result if @errors.any?

    check_doctor_availability
    return failure_result if @errors.any?

    create_appointment
  end

  private

  def validate_params
    required_fields = %i[user_id doctor_id clinic_id appointment_date start_time end_time consultation_type]
    required_fields.each do |field|
      if @params[field].blank?
        @errors << "#{field.to_s.humanize} is required"
      end
    end

    # Validate consultation type
    valid_types = %w[in_person video phone]
    unless valid_types.include?(@params[:consultation_type])
      @errors << "Consultation type must be one of: #{valid_types.join(', ')}"
    end
  end

  def validate_user_exists
    response = HttpClient.get(:users, "/api/v1/users/#{@params[:user_id]}")

    if response.is_a?(Hash) && response[:error]
      @errors << "User not found"
    elsif response.is_a?(HttpClient::Response) && !response.success?
       @errors << "User not found (Status: #{response.status})"
    end
  rescue HttpClient::ServiceUnavailable, HttpClient::CircuitOpen => e
    @errors << "Unable to verify user: #{e.message}"
  end

  def validate_doctor_and_clinic
    doctor_response = HttpClient.get(:doctors, "/api/v1/doctors/#{@params[:doctor_id]}")

    if doctor_response.is_a?(HttpClient::Response)
      if doctor_response.success?
        @doctor_data = doctor_response.body["doctor"] || doctor_response.body
      else
        @errors << "Doctor not found"
        return
      end
    elsif doctor_response.is_a?(Hash) && doctor_response[:error]
      @errors << "Doctor not found"
      return
    else
       @doctor_data = doctor_response
    end

    # Validate clinic matches doctor's clinic
    if @doctor_data["clinic_id"] != @params[:clinic_id]
      @errors << "Doctor is not associated with the specified clinic"
    end

    # Check if doctor is active and accepting patients
    unless @doctor_data["active"]
      @errors << "Doctor is not currently active"
    end

    unless @doctor_data["accepting_new_patients"]
      @errors << "Doctor is not accepting new patients"
    end

    # Get consultation fee
    @consultation_fee = @doctor_data["consultation_fee"]
  rescue HttpClient::ServiceUnavailable, HttpClient::CircuitOpen => e
    @errors << "Unable to verify doctor: #{e.message}"
  end

  def check_doctor_availability
    # Check if doctor has existing appointments at this time
    existing_appointments = Appointment
      .where(doctor_id: @params[:doctor_id])
      .where(appointment_date: @params[:appointment_date])
      .where.not(status: [ :cancelled, :no_show ])
      .where("(start_time::time, end_time::time) OVERLAPS (?::time, ?::time)", @params[:start_time], @params[:end_time])

    if existing_appointments.exists?
      @errors << "Doctor is not available at the requested time"
    end

    # Validate appointment date is not in the past
    if Date.parse(@params[:appointment_date].to_s) < Date.current
      @errors << "Appointment date cannot be in the past"
    end

    # Validate time range
    start_time = Time.parse(@params[:start_time].to_s)
    end_time = Time.parse(@params[:end_time].to_s)

    if start_time >= end_time
      @errors << "Start time must be before end time"
    end

    # Calculate and validate duration
    duration_minutes = ((end_time - start_time) / 60).to_i
    if duration_minutes < 15 || duration_minutes > 120
      @errors << "Appointment duration must be between 15 and 120 minutes"
    end
  rescue ArgumentError => e
    @errors << "Invalid date or time format: #{e.message}"
  end

  def create_appointment
    appointment = Appointment.new(
      user_id: @params[:user_id],
      doctor_id: @params[:doctor_id],
      clinic_id: @params[:clinic_id],
      appointment_date: @params[:appointment_date],
      start_time: @params[:start_time],
      end_time: @params[:end_time],
      consultation_type: @params[:consultation_type],
      consultation_fee: @consultation_fee,
      reason: @params[:reason],
      status: "pending",
      request_id: generate_request_id
    )

    if appointment.save
      success_result(appointment)
    else
      @errors = appointment.errors.full_messages
      failure_result
    end
  end

  def generate_request_id
    "APT-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  def success_result(appointment)
    {
      success: true,
      appointment: appointment,
      message: "Appointment booked successfully"
    }
  end

  def failure_result
    {
      success: false,
      errors: @errors,
      message: "Failed to book appointment"
    }
  end
end
