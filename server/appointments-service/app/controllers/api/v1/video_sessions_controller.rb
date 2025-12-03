# frozen_string_literal: true

module Api
  module V1
    class VideoSessionsController < ApplicationController
      before_action :set_video_session, only: [:show, :end]

      # POST /api/v1/video_sessions
      def create
        appointment = Appointment.find_by(id: params[:appointment_id])

        unless appointment
          render json: {
            errors: ["Appointment not found"],
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
          errors: ["Video session not found"],
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

      private

      def set_video_session
        @video_session = VideoSession.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {
          errors: ["Video session not found"],
          message: "Video session with id #{params[:id]} does not exist"
        }, status: :not_found
      end
    end
  end
end
