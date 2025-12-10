# frozen_string_literal: true

module Api
  module Internal
    # Internal API controller for user data
  # Called by other microservices to fetch user information
  #
  # @example Fetch user from Notifications Service
  #   response = HttpClient.get(:users, "/internal/users/#{user_id}")
  #   user_email = response.dig("user", "email")
  #   user_phone = response.dig("user", "phone_number")
  #
  # @example Batch fetch users
  #   response = HttpClient.post(:users, "/internal/users/batch", {
  #     user_ids: ["uuid1", "uuid2", "uuid3"]
  #   })
  #   users = response.dig("users")
  #
  class UsersController < BaseController
    # GET /internal/users/:id
    # Returns user data for internal service use
    #
    # @param id [String] User UUID
    # @return [JSON] User data without sensitive fields
    def show
      user = User.find(params[:id])

      render json: {
        user: user_response(user)
      }
    end

    # POST /internal/users/batch
    # Returns multiple users by IDs (for batch operations)
    #
    # @param user_ids [Array<String>] Array of user UUIDs
    # @return [JSON] Array of user data
    def batch
      user_ids = params.require(:user_ids)

      unless user_ids.is_a?(Array) && user_ids.length <= 100
        return render json: {
          error: "user_ids must be an array with max 100 items"
        }, status: :bad_request
      end

      users = User.where(id: user_ids)

      render json: {
        users: users.map { |user| user_response(user) },
        meta: {
          requested: user_ids.length,
          found: users.length
        }
      }
    end

    # GET /internal/users/by_email
    # Find user by email address
    #
    # @param email [String] User email
    # @return [JSON] User data or 404
    def by_email
      email = params.require(:email)
      user = User.find_by!(email: email.downcase)

      render json: {
        user: user_response(user)
      }
    end

    # GET /internal/users/:id/contact_info
    # Returns minimal contact information for notifications
    #
    # @param id [String] User UUID
    # @return [JSON] Contact info (email, phone, name)
    def contact_info
      user = User.find(params[:id])

      render json: {
        user_id: user.id,
        email: user.email,
        phone_number: user.phone_number,
        first_name: user.first_name,
        last_name: user.last_name,
        full_name: user.full_name,
        notification_preferences: notification_preferences(user)
      }
    end

    # GET /internal/users/:id/exists
    # Quick check if user exists (lightweight)
    #
    # @param id [String] User UUID
    # @return [JSON] { exists: true/false }
    def exists
      exists = User.exists?(params[:id])

      render json: { exists: exists }
    end

    private

    def user_response(user)
      {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        full_name: user.full_name,
        phone_number: user.phone_number,
        date_of_birth: user.date_of_birth,
        gender: user.gender,
        address: user.address,
        city: user.city,
        state: user.state,
        zip_code: user.zip_code,
        profile_picture_url: user.profile_picture_url,
        emergency_contact_name: user.emergency_contact_name,
        emergency_contact_phone: user.emergency_contact_phone,
        active: user.active,
        created_at: user.created_at,
        updated_at: user.updated_at
      }
    end

    def notification_preferences(user)
      # Default preferences if not explicitly set
      {
        email_enabled: true,
        sms_enabled: user.phone_number.present?,
        push_enabled: true
      }
    end
  end
end
end
