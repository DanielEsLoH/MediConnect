# frozen_string_literal: true

class NotificationPreferencesController < ApplicationController
  before_action :set_notification_preference, only: [:show, :update]

  # GET /notification_preferences/:user_id
  def show
    render json: @notification_preference
  end

  # PUT/PATCH /notification_preferences/:user_id
  def update
    if @notification_preference.update(notification_preference_params)
      render json: @notification_preference
    else
      render json: { errors: @notification_preference.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_notification_preference
    user_id = params[:id] || params[:user_id]
    return render json: { error: "user_id is required" }, status: :bad_request unless user_id.present?

    @notification_preference = NotificationPreference.for_user(user_id)
  end

  def notification_preference_params
    params.require(:notification_preference).permit(
      :email_enabled,
      :sms_enabled,
      :push_enabled,
      :appointment_reminders,
      :appointment_updates,
      :marketing_emails
    )
  end
end
