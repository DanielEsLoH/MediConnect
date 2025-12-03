# frozen_string_literal: true

class VideoSessionService
  attr_reader :errors

  def initialize(appointment)
    @appointment = appointment
    @errors = []
  end

  def create_session
    validate_appointment
    return failure_result if @errors.any?

    check_existing_session
    return success_result(@existing_session) if @existing_session

    build_video_session
  end

  def start_session(video_session)
    unless video_session.start!
      @errors << "Cannot start video session in current status: #{video_session.status}"
      return failure_result
    end

    # Update appointment status to in_progress
    @appointment.start!

    success_result(video_session, "Video session started successfully")
  end

  def end_session(video_session)
    unless video_session.end!
      @errors << "Cannot end video session in current status: #{video_session.status}"
      return failure_result
    end

    success_result(video_session, "Video session ended successfully")
  end

  private

  def validate_appointment
    unless @appointment.consultation_type == "video"
      @errors << "Appointment must be of type 'video' to create a video session"
    end

    unless %w[pending confirmed in_progress].include?(@appointment.status)
      @errors << "Cannot create video session for appointment with status: #{@appointment.status}"
    end
  end

  def check_existing_session
    @existing_session = VideoSession.find_by(appointment_id: @appointment.id)
  end

  def build_video_session
    video_session = VideoSession.new(
      appointment_id: @appointment.id,
      provider: "daily" # Default provider
    )

    if video_session.save
      success_result(video_session, "Video session created successfully")
    else
      @errors = video_session.errors.full_messages
      failure_result
    end
  end

  def success_result(video_session, message = nil)
    {
      success: true,
      video_session: video_session,
      patient_url: video_session.patient_url,
      doctor_url: video_session.doctor_url,
      message: message || "Video session retrieved successfully"
    }
  end

  def failure_result
    {
      success: false,
      errors: @errors,
      message: "Failed to process video session"
    }
  end
end
