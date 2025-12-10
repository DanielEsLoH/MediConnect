# frozen_string_literal: true

module Internal
  # Internal API controller for appointment data
  # Called by other microservices to fetch appointment information
  #
  # @example Fetch appointment from Payments Service
  #   response = HttpClient.get(:appointments, "/internal/appointments/#{appointment_id}")
  #   appointment_amount = response.dig("appointment", "amount")
  #   user_id = response.dig("appointment", "user_id")
  #
  # @example Get user's upcoming appointments
  #   response = HttpClient.get(:appointments, "/internal/appointments/by_user/#{user_id}")
  #   appointments = response.dig("appointments")
  #
  class AppointmentsController < BaseController
    # GET /internal/appointments/:id
    # Returns appointment data for internal service use
    #
    # @param id [String] Appointment UUID
    # @return [JSON] Appointment data
    def show
      appointment = Appointment.find(params[:id])

      render json: {
        appointment: appointment_response(appointment)
      }
    end

    # POST /internal/appointments/batch
    # Returns multiple appointments by IDs
    #
    # @param appointment_ids [Array<String>] Array of appointment UUIDs
    # @return [JSON] Array of appointment data
    def batch
      appointment_ids = params.require(:appointment_ids)

      unless appointment_ids.is_a?(Array) && appointment_ids.length <= 100
        return render json: {
          error: "appointment_ids must be an array with max 100 items"
        }, status: :bad_request
      end

      appointments = Appointment.where(id: appointment_ids)

      render json: {
        appointments: appointments.map { |apt| appointment_response(apt) },
        meta: {
          requested: appointment_ids.length,
          found: appointments.length
        }
      }
    end

    # GET /internal/appointments/by_user/:user_id
    # Returns appointments for a specific user
    #
    # @param user_id [String] User UUID
    # @param status [String] Optional status filter
    # @param from_date [String] Optional start date filter
    # @return [JSON] Array of appointments
    def by_user
      appointments = Appointment.where(user_id: params[:user_id])

      appointments = appointments.where(status: params[:status]) if params[:status].present?
      appointments = appointments.where("appointment_date >= ?", Date.parse(params[:from_date])) if params[:from_date].present?
      appointments = appointments.order(appointment_date: :asc, start_time: :asc)
      appointments = appointments.limit(params[:limit] || 50)

      render json: {
        appointments: appointments.map { |apt| appointment_response(apt) },
        meta: { count: appointments.length }
      }
    end

    # GET /internal/appointments/by_doctor/:doctor_id
    # Returns appointments for a specific doctor
    #
    # @param doctor_id [String] Doctor UUID
    # @param status [String] Optional status filter
    # @param date [String] Optional date filter
    # @return [JSON] Array of appointments
    def by_doctor
      appointments = Appointment.where(doctor_id: params[:doctor_id])

      appointments = appointments.where(status: params[:status]) if params[:status].present?
      appointments = appointments.where(appointment_date: Date.parse(params[:date])) if params[:date].present?
      appointments = appointments.order(appointment_date: :asc, start_time: :asc)
      appointments = appointments.limit(params[:limit] || 50)

      render json: {
        appointments: appointments.map { |apt| appointment_response(apt) },
        meta: { count: appointments.length }
      }
    end

    # GET /internal/appointments/:id/exists
    # Quick check if appointment exists
    #
    # @param id [String] Appointment UUID
    # @return [JSON] { exists: true/false, status: "..." }
    def exists
      appointment = Appointment.find_by(id: params[:id])

      render json: {
        exists: appointment.present?,
        status: appointment&.status,
        user_id: appointment&.user_id,
        doctor_id: appointment&.doctor_id
      }
    end

    # GET /internal/appointments/:id/payment_info
    # Returns payment-related information for an appointment
    #
    # @param id [String] Appointment UUID
    # @return [JSON] Payment-related appointment data
    def payment_info
      appointment = Appointment.find(params[:id])

      render json: {
        appointment_id: appointment.id,
        user_id: appointment.user_id,
        doctor_id: appointment.doctor_id,
        clinic_id: appointment.clinic_id,
        appointment_date: appointment.appointment_date,
        start_time: appointment.start_time,
        end_time: appointment.end_time,
        scheduled_datetime: appointment.scheduled_datetime,
        duration_minutes: appointment.duration_minutes,
        consultation_type: appointment.consultation_type,
        status: appointment.status,
        consultation_fee: appointment.consultation_fee,
        currency: "USD",
        notes: appointment.notes
      }
    end

    private

    def appointment_response(appointment)
      {
        id: appointment.id,
        user_id: appointment.user_id,
        doctor_id: appointment.doctor_id,
        clinic_id: appointment.clinic_id,
        appointment_date: appointment.appointment_date,
        start_time: appointment.start_time,
        end_time: appointment.end_time,
        scheduled_datetime: appointment.scheduled_datetime,
        end_datetime: appointment.end_datetime,
        duration_minutes: appointment.duration_minutes,
        consultation_type: appointment.consultation_type,
        status: appointment.status,
        consultation_fee: appointment.consultation_fee,
        notes: appointment.notes,
        prescription: appointment.prescription,
        cancellation_reason: appointment.cancellation_reason,
        cancelled_by: appointment.cancelled_by,
        cancelled_at: appointment.cancelled_at,
        confirmed_at: appointment.confirmed_at,
        completed_at: appointment.completed_at,
        created_at: appointment.created_at,
        updated_at: appointment.updated_at
      }
    end
  end
end
