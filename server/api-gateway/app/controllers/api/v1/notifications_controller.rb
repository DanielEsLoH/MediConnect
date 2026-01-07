# frozen_string_literal: true

module Api
  module V1
    # Controller for notification endpoints
    # Proxies requests to the notifications-service
    class NotificationsController < Api::BaseController
      before_action :authenticate_request!

      # GET /api/v1/notifications
      # Lists notifications for the current user
      #
      # @query_param [Integer] page Page number for pagination
      # @query_param [Integer] per_page Number of items per page
      # @query_param [Boolean] unread_only Filter to show only unread notifications
      def index
        proxy_request(
          service: :notifications,
          path: "/notifications",
          method: :get,
          params: filter_params.merge(user_id: current_user_id)
        )
      end

      # GET /api/v1/notifications/:id
      # Shows a specific notification
      def show
        proxy_request(
          service: :notifications,
          path: "/notifications/#{params[:id]}",
          method: :get,
          params: { user_id: current_user_id }
        )
      end

      # PATCH/PUT /api/v1/notifications/:id
      # Updates a notification (e.g., marks as read)
      def update
        proxy_request(
          service: :notifications,
          path: "/notifications/#{params[:id]}/mark_as_read",
          method: :post,
          params: { user_id: current_user_id }
        )
      end

      # GET /api/v1/notifications/unread_count
      # Returns the count of unread notifications for the current user
      def unread_count
        proxy_request(
          service: :notifications,
          path: "/notifications/unread_count",
          method: :get,
          params: { user_id: current_user_id }
        )
      end

      # POST /api/v1/notifications/mark_all_read
      # Marks all notifications as read for the current user
      def mark_all_read
        proxy_request(
          service: :notifications,
          path: "/notifications/mark_all_as_read",
          method: :post,
          params: { user_id: current_user_id }
        )
      end

      private

      def filter_params
        params.permit(:page, :per_page, :unread_only)
      end
    end
  end
end
