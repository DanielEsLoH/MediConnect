# frozen_string_literal: true

class AppointmentCancellationService
  attr_reader :errors

  CANCELLATION_POLICY_HOURS = 24

  def initialize(appointment, cancelled_by:, reason: nil)
    @appointment = appointment
    @cancelled_by = cancelled_by
    @reason = reason
    @errors = []
  end

  def call
    validate_can_cancel
    return failure_result if @errors.any?

    check_cancellation_policy
    # Note: Not failing on policy violation, just adding a warning

    cancel_appointment
  end

  private

  def validate_can_cancel
    unless @appointment.can_be_cancelled?
      @errors << "Appointment cannot be cancelled in its current status: #{@appointment.status}"
    end

    valid_cancelled_by = %w[patient doctor system]
    unless valid_cancelled_by.include?(@cancelled_by)
      @errors << "Invalid cancelled_by value. Must be one of: #{valid_cancelled_by.join(', ')}"
    end
  end

  def check_cancellation_policy
    return unless @appointment.scheduled_datetime

    hours_until_appointment = (@appointment.scheduled_datetime - Time.current) / 3600

    if hours_until_appointment < CANCELLATION_POLICY_HOURS && @cancelled_by == "patient"
      @policy_violation = true
      @policy_message = "Cancellation is within #{CANCELLATION_POLICY_HOURS} hours of appointment. " \
                       "Cancellation fees may apply."
    end
  end

  def cancel_appointment
    if @appointment.cancel!(cancelled_by: @cancelled_by, reason: @reason)
      result = {
        success: true,
        appointment: @appointment,
        message: "Appointment cancelled successfully"
      }

      if @policy_violation
        result[:warning] = @policy_message
      end

      result
    else
      @errors = @appointment.errors.full_messages
      failure_result
    end
  end

  def failure_result
    {
      success: false,
      errors: @errors,
      message: "Failed to cancel appointment"
    }
  end
end
