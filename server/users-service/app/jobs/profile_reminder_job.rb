# frozen_string_literal: true

class ProfileReminderJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    return if profile_complete?(user)

    Rails.logger.info("Sending profile reminder to user #{user.id} (#{user.email})")

    # TODO: Integrate with email service (e.g., SendGrid, SES)
    # For now, just log the action
    Rails.logger.info("Profile reminder sent to #{user.email}")
  rescue StandardError => e
    Rails.logger.error("Failed to send profile reminder to user #{user_id}: #{e.message}")
    raise
  end

  private

  def profile_complete?(user)
    required_fields = [:date_of_birth, :gender, :phone_number, :address, :city, :state, :zip_code]
    required_fields.all? { |field| user.send(field).present? }
  end
end
