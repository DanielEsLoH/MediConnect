# frozen_string_literal: true

class LiveKitService
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RoomCreationError < Error; end

  def initialize
    @api_key = ENV.fetch("LIVEKIT_API_KEY") { Rails.application.credentials.dig(:livekit, :api_key) }
    @api_secret = ENV.fetch("LIVEKIT_API_SECRET") { Rails.application.credentials.dig(:livekit, :api_secret) }
    @host = ENV.fetch("LIVEKIT_HOST", "http://localhost:7880")
    @ws_url = ENV.fetch("LIVEKIT_WS_URL", "ws://localhost:7880")

    validate_configuration!
  end

  # Create a room for an appointment
  # @param appointment_id [String, Integer] The appointment identifier
  # @param options [Hash] Optional room configuration
  # @option options [Integer] :empty_timeout Seconds to wait before closing an empty room (default: 300)
  # @option options [Integer] :max_participants Maximum number of participants allowed (default: 10)
  # @return [String] The generated room name
  def create_room(appointment_id, options = {})
    room_name = generate_room_name(appointment_id)

    begin
      room_service_client.create_room(
        name: room_name,
        empty_timeout: options.fetch(:empty_timeout, 300),
        max_participants: options.fetch(:max_participants, 10)
      )
      Rails.logger.info("[LiveKitService] Successfully created room: #{room_name}")
      room_name
    rescue StandardError => e
      Rails.logger.error("[LiveKitService] Failed to create room: #{e.message}")
      # In development, rooms are auto-created on join, so we can proceed
      # In production, this allows graceful degradation if LiveKit server is temporarily unavailable
      room_name
    end
  end

  # Generate an access token for a participant
  # @param room_name [String] The name of the room to join
  # @param user_id [String, Integer] The unique identifier for the user
  # @param user_name [String] The display name for the participant
  # @param is_owner [Boolean] Whether the participant has admin privileges (default: false)
  # @param ttl [Integer] Token time-to-live in seconds (default: 4 hours)
  # @return [String] A JWT token for the participant
  def generate_token(room_name:, user_id:, user_name:, is_owner: false, ttl: 4.hours.to_i)
    token = LiveKit::AccessToken.new(
      api_key: @api_key,
      api_secret: @api_secret,
      identity: user_id.to_s,
      name: user_name,
      ttl: ttl
    )

    token.video_grant = LiveKit::VideoGrant.new(
      roomJoin: true,
      room: room_name,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      roomAdmin: is_owner
    )

    token.to_jwt
  end

  # Delete a room
  # @param room_name [String] The name of the room to delete
  # @return [Boolean] True if deletion was successful, false otherwise
  def delete_room(room_name)
    room_service_client.delete_room(room_name)
    Rails.logger.info("[LiveKitService] Successfully deleted room: #{room_name}")
    true
  rescue StandardError => e
    Rails.logger.error("[LiveKitService] Failed to delete room #{room_name}: #{e.message}")
    false
  end

  # Get room info
  # @param room_name [String] The name of the room to retrieve
  # @return [LiveKit::Room, nil] The room object or nil if not found
  def get_room(room_name)
    rooms = room_service_client.list_rooms([ room_name ])
    rooms.first
  rescue StandardError => e
    Rails.logger.error("[LiveKitService] Failed to get room #{room_name}: #{e.message}")
    nil
  end

  # List all participants in a room
  # @param room_name [String] The name of the room
  # @return [Array<LiveKit::ParticipantInfo>] Array of participant objects
  def list_participants(room_name)
    room_service_client.list_participants(room_name)
  rescue StandardError => e
    Rails.logger.error("[LiveKitService] Failed to list participants for room #{room_name}: #{e.message}")
    []
  end

  # Remove a participant from a room
  # @param room_name [String] The name of the room
  # @param identity [String] The identity of the participant to remove
  # @return [Boolean] True if removal was successful
  def remove_participant(room_name, identity)
    room_service_client.remove_participant(room_name, identity)
    Rails.logger.info("[LiveKitService] Removed participant #{identity} from room #{room_name}")
    true
  rescue StandardError => e
    Rails.logger.error("[LiveKitService] Failed to remove participant #{identity} from room #{room_name}: #{e.message}")
    false
  end

  # Get the WebSocket URL for clients
  # @return [String] The WebSocket URL for LiveKit connection
  def websocket_url
    @ws_url
  end

  # Get the HTTP host URL
  # @return [String] The HTTP host URL for LiveKit API
  def host_url
    @host
  end

  private

  def validate_configuration!
    if @api_key.blank? || @api_secret.blank?
      raise ConfigurationError, "LiveKit API key and secret must be configured"
    end

    if @api_secret.length < 32
      raise ConfigurationError, "LiveKit API secret must be at least 32 characters"
    end
  end

  def room_service_client
    @room_service_client ||= LiveKit::RoomServiceClient.new(@host, @api_key, @api_secret)
  end

  def generate_room_name(appointment_id)
    "mediconnect-#{appointment_id}-#{SecureRandom.hex(4)}"
  end
end
