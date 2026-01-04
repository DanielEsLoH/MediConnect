# frozen_string_literal: true

module Api
  module V1
    class VideoSessionsController < ApplicationController
      before_action :set_video_session, only: [ :show, :end, :token, :connection_info ]

      # POST /api/v1/video_sessions
      def create
        appointment = Appointment.find_by(id: params[:appointment_id])

        unless appointment
          render json: {
            errors: [ "Appointment not found" ],
            message: "Appointment with id #{params[:appointment_id]} does not exist"
          }, status: :not_found
          return
        end

        result = VideoSessionService.new(appointment).create_session

        if result[:success]
          render json: {
            video_session: result[:video_session].as_json,
            patient_url: result[:patient_url],
            doctor_url: result[:doctor_url],
            message: result[:message]
          }, status: :created
        else
          render json: {
            errors: result[:errors],
            message: result[:message]
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/video_sessions/:id
      def show
        service = VideoSessionService.new(@video_session.appointment)

        render json: {
          video_session: @video_session.as_json,
          patient_url: @video_session.patient_url,
          doctor_url: @video_session.doctor_url,
          appointment: @video_session.appointment.as_json
        }, status: :ok
      end

      # POST /api/v1/video_sessions/:id/start
      def start
        video_session = VideoSession.find(params[:id])
        result = VideoSessionService.new(video_session.appointment).start_session(video_session)

        if result[:success]
          render json: {
            video_session: result[:video_session].as_json,
            patient_url: result[:patient_url],
            doctor_url: result[:doctor_url],
            message: result[:message]
          }, status: :ok
        else
          render json: {
            errors: result[:errors],
            message: result[:message]
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: {
          errors: [ "Video session not found" ],
          message: "Video session with id #{params[:id]} does not exist"
        }, status: :not_found
      end

      # POST /api/v1/video_sessions/:id/end
      def end
        result = VideoSessionService.new(@video_session.appointment).end_session(@video_session)

        if result[:success]
          render json: {
            video_session: result[:video_session].as_json,
            duration_minutes: result[:video_session].duration_minutes,
            message: result[:message]
          }, status: :ok
        else
          render json: {
            errors: result[:errors],
            message: result[:message]
          }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/video_sessions/:id/token
      # Returns a LiveKit token for the specified user to join the video session
      def token
        user_id = params[:user_id]
        user_name = params[:user_name] || "Participant"
        is_doctor = params[:is_doctor] == "true" || params[:is_doctor] == true

        unless user_id.present?
          render json: {
            errors: [ "user_id is required" ],
            message: "Please provide a user_id parameter"
          }, status: :bad_request
          return
        end

        token = @video_session.generate_participant_token(
          user_id: user_id,
          user_name: user_name,
          is_owner: is_doctor
        )

        render json: {
          token: token,
          room_name: @video_session.room_name,
          websocket_url: @video_session.livekit_websocket_url,
          expires_in: 4.hours.to_i
        }, status: :ok
      end

      # GET /api/v1/video_sessions/:id/connection_info
      # Returns all information needed for a client to connect to the video session
      def connection_info
        user_id = params[:user_id]
        user_name = params[:user_name] || "Participant"
        is_doctor = params[:is_doctor] == "true" || params[:is_doctor] == true

        unless user_id.present?
          render json: {
            errors: [ "user_id is required" ],
            message: "Please provide a user_id parameter"
          }, status: :bad_request
          return
        end

        info = @video_session.connection_info(
          user_id: user_id,
          user_name: user_name,
          is_doctor: is_doctor
        )

        render json: {
          connection_info: info,
          video_session: @video_session.as_json,
          message: "Connection info retrieved successfully"
        }, status: :ok
      end

      private

      def set_video_session
        @video_session = VideoSession.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          errors: [ "Video session not found" ],
          message: "Video session with id #{params[:id]} does not exist"
        }, status: :not_found
      end
    end
  end
end
