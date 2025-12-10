# frozen_string_literal: true

module Api
  module V1
    # Controller for appointment management endpoints
    # Proxies requests to the appointments-service
    class AppointmentsController < Api::BaseController
      before_action :authenticate_request!

      # GET /api/v1/appointments
      # Lists appointments for the current user
      # Admins can see all appointments with filters
      #
      # @query_param [Integer] page Page number for pagination
      # @query_param [Integer] per_page Number of items per page
      # @query_param [String] status Filter by status (pending, confirmed, completed, cancelled)
      # @query_param [Date] start_date Filter by start date
      # @query_param [Date] end_date Filter by end date
      def index
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments",
          method: :get,
          params: filter_params.merge(user_scope_params)
        )
      end

      # GET /api/v1/appointments/:id
      # Shows a specific appointment
      def show
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/#{params[:id]}",
          method: :get
        )
      end

      # POST /api/v1/appointments
      # Creates a new appointment
      #
      # @body_param [Integer] doctor_id The doctor's ID
      # @body_param [DateTime] scheduled_at Appointment date and time
      # @body_param [String] type Appointment type
      # @body_param [String] reason Reason for visit
      # @body_param [String] notes Additional notes
      def create
        # Ensure user_id is set from authenticated user
        appointment_data = appointment_params.to_h
        appointment_data[:user_id] = current_user_id unless current_user_has_role?(:admin)

        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments",
          method: :post,
          body: { appointment: appointment_data }
        )
      end

      # PATCH/PUT /api/v1/appointments/:id
      # Updates an appointment
      def update
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/#{params[:id]}",
          method: :patch,
          body: { appointment: appointment_update_params.to_h }
        )
      end

      # DELETE /api/v1/appointments/:id
      # Cancels/deletes an appointment
      def destroy
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/#{params[:id]}",
          method: :delete
        )
      end

      # GET /api/v1/appointments/upcoming
      # Lists upcoming appointments for the current user
      def upcoming
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/upcoming",
          method: :get,
          params: pagination_params.merge(user_scope_params)
        )
      end

      # GET /api/v1/appointments/past
      # Lists past appointments for the current user
      def past
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/past",
          method: :get,
          params: pagination_params.merge(user_scope_params)
        )
      end

      # POST /api/v1/appointments/:id/confirm
      # Confirms a pending appointment (doctor action)
      def confirm
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/#{params[:id]}/confirm",
          method: :post
        )
      end

      # POST /api/v1/appointments/:id/cancel
      # Cancels an appointment
      #
      # @body_param [String] reason Cancellation reason
      def cancel
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/#{params[:id]}/cancel",
          method: :post,
          body: cancel_params.to_h
        )
      end

      # POST /api/v1/appointments/:id/reschedule
      # Reschedules an appointment to a new time
      #
      # @body_param [DateTime] scheduled_at New appointment date and time
      # @body_param [String] reason Reason for rescheduling
      def reschedule
        proxy_request(
          service: :appointments,
          path: "/api/v1/appointments/#{params[:id]}/reschedule",
          method: :post,
          body: reschedule_params.to_h
        )
      end

      private

      def appointment_params
        params.require(:appointment).permit(
          :user_id,
          :doctor_id,
          :clinic_id,
          :appointment_date,
          :start_time,
          :end_time,
          :consultation_type,
          :scheduled_at,
          :duration,
          :type,
          :reason,
          :notes,
          :location,
          :is_virtual
        )
      end

      def appointment_update_params
        params.require(:appointment).permit(
          :scheduled_at,
          :duration,
          :type,
          :reason,
          :notes,
          :location,
          :is_virtual
        )
      end

      def filter_params
        params.permit(
          :page,
          :per_page,
          :status,
          :start_date,
          :end_date,
          :doctor_id,
          :sort,
          :order
        )
      end

      def pagination_params
        params.permit(:page, :per_page)
      end

      def cancel_params
        params.permit(:reason)
      end

      def reschedule_params
        params.permit(:scheduled_at, :reason)
      end

      # Adds user scope parameters based on role
      # Regular users can only see their own appointments
      # Doctors can see appointments they're part of
      # Admins can see all appointments
      def user_scope_params
        return {} if current_user_has_role?(:admin)

        if current_user_has_role?(:doctor)
          { doctor_user_id: current_user_id }
        else
          { user_id: current_user_id }
        end
      end
    end
  end
end
