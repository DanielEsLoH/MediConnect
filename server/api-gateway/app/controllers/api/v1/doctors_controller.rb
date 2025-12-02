# frozen_string_literal: true

module Api
  module V1
    # Controller for doctor-related endpoints
    # Proxies requests to the doctors-service
    class DoctorsController < Api::BaseController
      # Optional authentication - some endpoints may show more data when authenticated
      before_action :authenticate_request, only: [:index, :show, :search]

      # GET /api/v1/doctors
      # Lists all doctors with optional filtering
      #
      # @query_param [Integer] page Page number for pagination
      # @query_param [Integer] per_page Number of items per page
      # @query_param [String] specialty Filter by specialty
      # @query_param [String] city Filter by city
      # @query_param [Boolean] accepting_patients Filter by availability
      # @query_param [Float] rating_min Minimum rating filter
      def index
        proxy_request(
          service: :doctors,
          path: "/api/v1/doctors",
          method: :get,
          params: filter_params
        )
      end

      # GET /api/v1/doctors/:id
      # Shows a specific doctor's profile
      def show
        proxy_request(
          service: :doctors,
          path: "/api/v1/doctors/#{params[:id]}",
          method: :get
        )
      end

      # GET /api/v1/doctors/search
      # Searches for doctors by name, specialty, or location
      #
      # @query_param [String] q Search query
      # @query_param [String] specialty Specialty to search within
      # @query_param [Float] lat Latitude for location-based search
      # @query_param [Float] lng Longitude for location-based search
      # @query_param [Integer] radius Search radius in miles
      def search
        proxy_request(
          service: :doctors,
          path: "/api/v1/doctors/search",
          method: :get,
          params: search_params
        )
      end

      # GET /api/v1/doctors/specialties
      # Lists all available specialties
      def specialties
        proxy_request(
          service: :doctors,
          path: "/api/v1/doctors/specialties",
          method: :get
        )
      end

      # GET /api/v1/doctors/:id/availability
      # Gets a doctor's available time slots
      #
      # @query_param [Date] date Specific date to check
      # @query_param [Date] start_date Start of date range
      # @query_param [Date] end_date End of date range
      def availability
        proxy_request(
          service: :doctors,
          path: "/api/v1/doctors/#{params[:id]}/availability",
          method: :get,
          params: availability_params
        )
      end

      # GET /api/v1/doctors/:id/reviews
      # Gets reviews for a specific doctor
      #
      # @query_param [Integer] page Page number for pagination
      # @query_param [Integer] per_page Number of items per page
      # @query_param [String] sort Sort order (recent, rating_high, rating_low)
      def reviews
        proxy_request(
          service: :doctors,
          path: "/api/v1/doctors/#{params[:id]}/reviews",
          method: :get,
          params: reviews_params
        )
      end

      private

      def filter_params
        params.permit(
          :page,
          :per_page,
          :specialty,
          :city,
          :state,
          :accepting_patients,
          :rating_min,
          :insurance,
          :language,
          :gender,
          :sort,
          :order
        )
      end

      def search_params
        params.permit(
          :q,
          :specialty,
          :lat,
          :lng,
          :radius,
          :page,
          :per_page
        )
      end

      def availability_params
        params.permit(:date, :start_date, :end_date, :duration)
      end

      def reviews_params
        params.permit(:page, :per_page, :sort)
      end
    end
  end
end
