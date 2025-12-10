# frozen_string_literal: true

module Api
  module V1
    class AppointmentsController < ApplicationController
      before_action :set_appointment, only: [ :show, :update, :destroy, :confirm, :cancel, :complete ]

      # GET /api/v1/appointments
      def index
        appointments = Appointment.all

        # Apply filters
        appointments = appointments.for_user(params[:user_id]) if params[:user_id].present?
        appointments = appointments.for_doctor(params[:doctor_id]) if params[:doctor_id].present?
        appointments = appointments.for_clinic(params[:clinic_id]) if params[:clinic_id].present?
        appointments = appointments.by_status(params[:status]) if params[:status].present?
        appointments = appointments.by_consultation_type(params[:consultation_type]) if params[:consultation_type].present?

        # Date range filters
        if params[:start_date].present? && params[:end_date].present?
          appointments = appointments.between_dates(params[:start_date], params[:end_date])
        elsif params[:date].present?
          appointments = appointments.on_date(params[:date])
        end

        # Order
        appointments = appointments.ordered_by_date

        # Pagination
        page = params[:page] || 1
        per_page = params[:per_page] || 20

        appointments = appointments.page(page).per(per_page)

        render json: {
          appointments: appointments.as_json,
          meta: pagination_meta(appointments)
        }, status: :ok
      end

      # GET /api/v1/appointments/:id
      def show
        render json: {
          appointment: @appointment.as_json(include: :video_session)
        }, status: :ok
      end

      # POST /api/v1/appointments
      def create
        result = AppointmentBookingService.new(appointment_params).call

        if result[:success]
          render json: {
            appointment: result[:appointment].as_json,
            message: result[:message]
          }, status: :created
        else
          render json: {
            errors: result[:errors],
            message: result[:message]
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/appointments/:id
      def update
        if @appointment.update(update_params)
          render json: {
            appointment: @appointment.as_json,
            message: "Appointment updated successfully"
          }, status: :ok
        else
          render json: {
            errors: @appointment.errors.full_messages,
            message: "Failed to update appointment"
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/appointments/:id
      def destroy
        if @appointment.destroy
          render json: {
            message: "Appointment deleted successfully"
          }, status: :ok
        else
          render json: {
            errors: @appointment.errors.full_messages,
            message: "Failed to delete appointment"
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/appointments/:id/confirm
      def confirm
        if @appointment.confirm!
          render json: {
            appointment: @appointment.as_json,
            message: "Appointment confirmed successfully"
          }, status: :ok
        else
          render json: {
            errors: @appointment.errors.full_messages,
            message: "Failed to confirm appointment"
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/appointments/:id/cancel
      def cancel
        result = AppointmentCancellationService.new(
          @appointment,
          cancelled_by: params[:cancelled_by],
          reason: params[:reason]
        ).call

        if result[:success]
          response_data = {
            appointment: result[:appointment].as_json,
            message: result[:message]
          }
          response_data[:warning] = result[:warning] if result[:warning]

          render json: response_data, status: :ok
        else
          render json: {
            errors: result[:errors],
            message: result[:message]
          }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/appointments/:id/complete
      def complete
        if @appointment.complete!(
          notes: params[:notes],
          prescription: params[:prescription]
        )
          render json: {
            appointment: @appointment.as_json,
            message: "Appointment completed successfully"
          }, status: :ok
        else
          render json: {
            errors: @appointment.errors.full_messages,
            message: "Failed to complete appointment"
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/appointments/upcoming
      def upcoming
        user_id = params[:user_id]
        doctor_id = params[:doctor_id]

        if user_id.blank? && doctor_id.blank?
          render json: {
            errors: [ "user_id or doctor_id is required" ],
            message: "Missing required parameter"
          }, status: :bad_request
          return
        end

        appointments = Appointment.upcoming

        if user_id.present?
          appointments = appointments.for_user(user_id)
        elsif doctor_id.present?
          appointments = appointments.for_doctor(doctor_id)
        end

        appointments = appointments.ordered_by_date.limit(params[:limit] || 10)

        render json: {
          appointments: appointments.as_json
        }, status: :ok
      end

      # GET /api/v1/appointments/history
      def history
        user_id = params[:user_id]
        doctor_id = params[:doctor_id]

        if user_id.blank? && doctor_id.blank?
          render json: {
            errors: [ "user_id or doctor_id is required" ],
            message: "Missing required parameter"
          }, status: :bad_request
          return
        end

        appointments = Appointment.past

        if user_id.present?
          appointments = appointments.for_user(user_id)
        elsif doctor_id.present?
          appointments = appointments.for_doctor(doctor_id)
        end

        page = params[:page] || 1
        per_page = params[:per_page] || 20

        appointments = appointments.recent.page(page).per(per_page)

        render json: {
          appointments: appointments.as_json,
          meta: pagination_meta(appointments)
        }, status: :ok
      end

      private

      def set_appointment
        @appointment = Appointment.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          errors: [ "Appointment not found" ],
          message: "Appointment with id #{params[:id]} does not exist"
        }, status: :not_found
      end

      def appointment_params
        params.require(:appointment).permit(
          :user_id,
          :doctor_id,
          :clinic_id,
          :appointment_date,
          :start_time,
          :end_time,
          :consultation_type,
          :reason
        )
      end

      def update_params
        params.require(:appointment).permit(
          :appointment_date,
          :start_time,
          :end_time,
          :reason,
          :notes
        )
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          next_page: collection.next_page,
          prev_page: collection.prev_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count
        }
      end
    end
  end
end
