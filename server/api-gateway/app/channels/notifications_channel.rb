# frozen_string_literal: true

# Channel for real-time notification updates
# Clients subscribe to receive notifications in real-time
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from notifications_stream
    Rails.logger.info "[NotificationsChannel] User #{current_user_id} subscribed"
  end

  def unsubscribed
    Rails.logger.info "[NotificationsChannel] User #{current_user_id} unsubscribed"
  end

  private

  def notifications_stream
    "notifications_user_#{current_user_id}"
  end

  class << self
    # Broadcast a notification to a specific user
    #
    # @param user_id [Integer, String] The user ID to send the notification to
    # @param notification [Hash] The notification data
    #
    # @example
    #   NotificationsChannel.broadcast_to_user(1, { id: 1, title: "New message" })
    def broadcast_to_user(user_id, notification)
      ActionCable.server.broadcast(
        "notifications_user_#{user_id}",
        { type: "notification", notification: notification }
      )
    end

    # Broadcast a notification to multiple users
    #
    # @param user_ids [Array<Integer, String>] Array of user IDs
    # @param notification [Hash] The notification data
    def broadcast_to_users(user_ids, notification)
      user_ids.each do |user_id|
        broadcast_to_user(user_id, notification)
      end
    end
  end
end
