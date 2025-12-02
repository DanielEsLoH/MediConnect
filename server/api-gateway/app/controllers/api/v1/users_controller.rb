# frozen_string_literal: true

module Api
  module V1
    # Controller for user management endpoints
    # Proxies requests to the users-service
    class UsersController < Api::BaseController
      before_action :authenticate_request!, except: [:create]
      before_action :require_admin!, only: [:index]

      # GET /api/v1/users
      # Lists all users (admin only)
      #
      # @query_param [Integer] page Page number for pagination
      # @query_param [Integer] per_page Number of items per page
      # @query_param [String] role Filter by user role
      # @query_param [String] status Filter by user status
      def index
        proxy_request(
          service: :users,
          path: "/api/v1/users",
          method: :get,
          params: filter_params
        )
      end

      # GET /api/v1/users/:id
      # Shows a specific user
      # Users can only view their own profile unless admin
      def show
        authorize_user_access!

        proxy_request(
          service: :users,
          path: "/api/v1/users/#{params[:id]}",
          method: :get
        )
      end

      # POST /api/v1/users
      # Creates a new user (registration)
      # This endpoint is public for user registration
      def create
        proxy_request(
          service: :users,
          path: "/api/v1/users",
          method: :post,
          body: user_params.to_h
        )
      end

      # PATCH/PUT /api/v1/users/:id
      # Updates a user
      # Users can only update their own profile unless admin
      def update
        authorize_user_access!

        proxy_request(
          service: :users,
          path: "/api/v1/users/#{params[:id]}",
          method: :patch,
          body: user_update_params.to_h
        )
      end

      # GET /api/v1/users/search
      # Searches for users (admin only typically)
      def search
        proxy_request(
          service: :users,
          path: "/api/v1/users/search",
          method: :get,
          params: search_params
        )
      end

      private

      def user_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation,
          :first_name,
          :last_name,
          :phone,
          :date_of_birth,
          :role
        )
      end

      def user_update_params
        params.require(:user).permit(
          :first_name,
          :last_name,
          :phone,
          :date_of_birth,
          :avatar_url,
          :address,
          :city,
          :state,
          :zip_code,
          :country
        )
      end

      def filter_params
        params.permit(:page, :per_page, :role, :status, :sort, :order)
      end

      def search_params
        params.permit(:q, :page, :per_page, :role)
      end

      # Ensures user can only access their own data unless admin
      def authorize_user_access!
        return if current_user_has_role?(:admin)
        return if params[:id].to_s == current_user_id.to_s

        render json: ErrorResponse.forbidden(
          "You can only access your own user data",
          request_id: request_id
        ), status: :forbidden
      end
    end
  end
end
