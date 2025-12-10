# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :set_notification, only: [ :show, :mark_as_read, :destroy ]

  # GET /notifications
  def index
    @notifications = Notification.for_user(params[:user_id])
                                  .by_type(params[:notification_type])
                                  .by_status(params[:status])
                                  .recent
                                  .page(params[:page])
                                  .per(params[:per_page] || 20)

    render json: {
      notifications: @notifications.as_json,
      meta: {
        current_page: @notifications.current_page,
        total_pages: @notifications.total_pages,
        total_count: @notifications.total_count,
        per_page: @notifications.limit_value
      }
    }
  end

  # GET /notifications/unread_count
  def unread_count
    user_id = params[:user_id]
    return render json: { error: "user_id is required" }, status: :bad_request unless user_id.present?

    count = Notification.for_user(user_id).unread.count

    render json: { unread_count: count }
  end

  # GET /notifications/:id
  def show
    render json: @notification
  end

  # POST /notifications/:id/mark_as_read
  def mark_as_read
    if @notification.mark_as_read!
      render json: @notification
    else
      render json: { error: "Failed to mark notification as read" }, status: :unprocessable_entity
    end
  end

  # POST /notifications/mark_all_as_read
  def mark_all_as_read
    user_id = params[:user_id]
    return render json: { error: "user_id is required" }, status: :bad_request unless user_id.present?

    count = Notification.for_user(user_id).unread.update_all(
      read_at: Time.current,
      status: :read,
      updated_at: Time.current
    )

    render json: { marked_count: count, message: "#{count} notifications marked as read" }
  end

  # DELETE /notifications/:id
  def destroy
    if @notification.destroy
      head :no_content
    else
      render json: { error: "Failed to delete notification" }, status: :unprocessable_entity
    end
  end

  # POST /notifications (for manual notification creation)
  def create
    @notification = Notification.new(notification_params)

    if @notification.save
      render json: @notification, status: :created
    else
      render json: { errors: @notification.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Notification not found" }, status: :not_found
  end

  def notification_params
    params.require(:notification).permit(
      :user_id,
      :notification_type,
      :title,
      :message,
      :delivery_method,
      :priority,
      :scheduled_for,
      data: {}
    )
  end
end
