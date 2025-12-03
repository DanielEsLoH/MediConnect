# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  default from: ENV.fetch("SMTP_FROM_EMAIL", "noreply@mediconnect.com")

  def welcome_email
    @user_name = params[:user_name]
    @notification = params[:notification]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def appointment_confirmation
    @user_name = params[:user_name]
    @notification = params[:notification]
    @appointment_date = @notification.data["scheduled_datetime"]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def appointment_reminder
    @user_name = params[:user_name]
    @notification = params[:notification]
    @appointment_date = @notification.data["scheduled_datetime"]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def appointment_cancellation
    @user_name = params[:user_name]
    @notification = params[:notification]
    @reason = @notification.data["cancellation_reason"]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def appointment_completed
    @user_name = params[:user_name]
    @notification = params[:notification]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def password_reset
    @user_name = params[:user_name]
    @notification = params[:notification]
    @reset_token = @notification.data["reset_token"]
    @reset_url = @notification.data["reset_url"]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def payment_receipt
    @user_name = params[:user_name]
    @notification = params[:notification]
    @amount = @notification.data["amount"]
    @transaction_id = @notification.data["transaction_id"]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end

  def general_notification
    @user_name = params[:user_name]
    @notification = params[:notification]

    mail(
      to: params[:to],
      subject: params[:subject]
    )
  end
end
