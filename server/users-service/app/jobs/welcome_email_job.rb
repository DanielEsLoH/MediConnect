# frozen_string_literal: true

class WelcomeEmailJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    Rails.logger.info("Sending welcome email to user #{user.id} (#{user.email})")

    # TODO: Integrate with email service (e.g., SendGrid, SES)
    # For now, just log the action
    Rails.logger.info("Welcome email sent to #{user.email}")
  rescue StandardError => e
    Rails.logger.error("Failed to send welcome email to user #{user_id}: #{e.message}")
    raise
  end
end
