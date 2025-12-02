# frozen_string_literal: true

class AuthenticationService
  class AuthenticationError < StandardError; end
  class ValidationError < StandardError; end

  class << self
    def authenticate(email, password)
      user = User.active.find_by(email: email.downcase)
      raise AuthenticationError, "Invalid email or password" unless user&.authenticate(password)

      user
    end

    def register(user_params)
      validate_password_strength(user_params[:password])

      user = User.new(user_params)
      raise ValidationError, user.errors.full_messages.join(", ") unless user.save

      # Enqueue welcome email job
      WelcomeEmailJob.perform_async(user.id)

      user
    end

    private

    def validate_password_strength(password)
      return if password.blank?

      errors = []
      errors << "Password must be at least 8 characters long" if password.length < 8
      errors << "Password must contain at least one uppercase letter" unless password.match?(/[A-Z]/)
      errors << "Password must contain at least one lowercase letter" unless password.match?(/[a-z]/)
      errors << "Password must contain at least one digit" unless password.match?(/\d/)

      raise ValidationError, errors.join(", ") if errors.any?
    end
  end
end
