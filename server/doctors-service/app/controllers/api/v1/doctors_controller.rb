# frozen_string_literal: true

module Api
  module V1
    class DoctorsController < ApplicationController
      before_action :set_doctor, only: [:show, :availability, :reviews]

      # GET /api/v1/doctors
      def index
        @doctors = Doctor.active.includes(:specialty, :clinic)

        @doctors = @doctors.by_specialty(params[:specialty_id]) if params[:specialty_id].present?
        @doctors = @doctors.by_clinic(params[:clinic_id]) if params[:clinic_id].present?
        @doctors = @doctors.accepting_patients if params[:accepting_patients] == "true"
        @doctors = @doctors.by_language(params[:language]) if params[:language].present?

        @doctors = @doctors.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          doctors: @doctors.as_json(
            include: {
              specialty: { only: [:id, :name] },
              clinic: { only: [:id, :name, :city, :state] }
            },
            methods: [:average_rating, :total_reviews]
          ),
          meta: pagination_meta(@doctors)
        }
      end

      # GET /api/v1/doctors/:id
      def show
        render json: {
          doctor: @doctor.as_json(
            include: {
              specialty: { only: [:id, :name, :description] },
              clinic: { only: [:id, :name, :address, :city, :state, :zip_code, :phone_number] },
              schedules: { only: [:id, :day_of_week, :start_time, :end_time, :slot_duration_minutes] }
            },
            methods: [:average_rating, :total_reviews]
          )
        }
      end

      # GET /api/v1/doctors/search
      def search
        @doctors = Doctor.active.includes(:specialty, :clinic)

        if params[:query].present?
          @doctors = @doctors.search_by_text(params[:query])
        end

        @doctors = @doctors.by_specialty(params[:specialty_id]) if params[:specialty_id].present?
        @doctors = @doctors.by_language(params[:language]) if params[:language].present?
        @doctors = @doctors.accepting_patients if params[:accepting_patients] == "true"

        @doctors = @doctors.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          doctors: @doctors.as_json(
            include: {
              specialty: { only: [:id, :name] },
              clinic: { only: [:id, :name, :city, :state] }
            },
            methods: [:average_rating, :total_reviews]
          ),
          meta: pagination_meta(@doctors)
        }
      end

      # GET /api/v1/doctors/:id/availability
      def availability
        date = params[:date].present? ? Date.parse(params[:date]) : Date.today
        availability_service = AvailabilityService.new(@doctor)

        slots = availability_service.available_slots(date)

        render json: {
          doctor_id: @doctor.id,
          date: date,
          available_slots: slots,
          next_available_date: availability_service.next_available_date(date)
        }
      rescue ArgumentError => e
        render json: { error: "Invalid date format" }, status: :bad_request
      end

      # GET /api/v1/doctors/:id/reviews
      def reviews
        @reviews = @doctor.reviews.recent.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          reviews: @reviews.as_json,
          meta: pagination_meta(@reviews),
          stats: {
            average_rating: @doctor.average_rating,
            total_reviews: @doctor.total_reviews
          }
        }
      end

      # GET /api/v1/doctors/specialties
      def specialties
        @specialties = Specialty.with_doctors.order(:name)

        render json: {
          specialties: @specialties.as_json(
            methods: [:doctors_count]
          )
        }
      end

      private

      def set_doctor
        @doctor = Doctor.active.includes(:specialty, :clinic, :schedules).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Doctor not found" }, status: :not_found
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
