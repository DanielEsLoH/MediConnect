# frozen_string_literal: true

require "rails_helper"

# Stub LiveKit module and classes for testing
# This allows us to test the service without requiring a real LiveKit server
module LiveKit
  class AccessToken
    attr_accessor :identity, :name, :ttl, :video_grant

    def initialize(api_key:, api_secret:, **options)
      @api_key = api_key
      @api_secret = api_secret
    end

    def to_jwt
      "stubbed_jwt_token"
    end
  end

  class VideoGrant
    def initialize(**options)
      @options = options
    end
  end

  class RoomServiceClient
    def initialize(host, api_key, api_secret)
      @host = host
      @api_key = api_key
      @api_secret = api_secret
    end
  end
end unless defined?(LiveKit)

RSpec.describe LiveKitService do
  # LiveKit environment variables for testing
  let(:api_key) { "devkey" }
  let(:api_secret) { "secret_that_is_at_least_32_characters_long" }
  let(:host) { "http://localhost:7880" }
  let(:ws_url) { "ws://localhost:7880" }

  before do
    # Set up test environment variables
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("LIVEKIT_API_KEY").and_return(api_key)
    allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return(api_secret)
    allow(ENV).to receive(:fetch).with("LIVEKIT_HOST", anything).and_return(host)
    allow(ENV).to receive(:fetch).with("LIVEKIT_WS_URL", anything).and_return(ws_url)
  end

  describe "#initialize" do
    context "with valid configuration" do
      it "initializes successfully with valid credentials" do
        expect { described_class.new }.not_to raise_error
      end

      it "stores the API key from environment" do
        service = described_class.new
        expect(service.host_url).to eq(host)
      end

      it "stores the WebSocket URL from environment" do
        service = described_class.new
        expect(service.websocket_url).to eq(ws_url)
      end
    end

    context "with missing configuration" do
      it "raises ConfigurationError when API key is missing" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_KEY").and_return(nil)

        expect { described_class.new }.to raise_error(
          LiveKitService::ConfigurationError,
          "LiveKit API key and secret must be configured"
        )
      end

      it "raises ConfigurationError when API secret is missing" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return(nil)

        expect { described_class.new }.to raise_error(
          LiveKitService::ConfigurationError,
          "LiveKit API key and secret must be configured"
        )
      end

      it "raises ConfigurationError when API key is blank" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_KEY").and_return("")

        expect { described_class.new }.to raise_error(
          LiveKitService::ConfigurationError,
          "LiveKit API key and secret must be configured"
        )
      end

      it "raises ConfigurationError when API secret is blank" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return("")

        expect { described_class.new }.to raise_error(
          LiveKitService::ConfigurationError,
          "LiveKit API key and secret must be configured"
        )
      end
    end

    context "with invalid secret length" do
      it "raises ConfigurationError when API secret is too short" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return("short_secret")

        expect { described_class.new }.to raise_error(
          LiveKitService::ConfigurationError,
          "LiveKit API secret must be at least 32 characters"
        )
      end

      it "raises ConfigurationError when API secret is exactly 31 characters" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return("a" * 31)

        expect { described_class.new }.to raise_error(
          LiveKitService::ConfigurationError,
          "LiveKit API secret must be at least 32 characters"
        )
      end

      it "accepts API secret of exactly 32 characters" do
        allow(ENV).to receive(:fetch).with("LIVEKIT_API_SECRET").and_return("a" * 32)

        expect { described_class.new }.not_to raise_error
      end
    end
  end

  describe "#create_room" do
    let(:service) { described_class.new }
    let(:appointment_id) { SecureRandom.uuid }
    let(:room_service_client) { double("RoomServiceClient") }

    before do
      allow(service).to receive(:room_service_client).and_return(room_service_client)
    end

    context "when room creation succeeds" do
      before do
        allow(room_service_client).to receive(:create_room).and_return(true)
      end

      it "returns a room name starting with mediconnect prefix" do
        room_name = service.create_room(appointment_id)

        expect(room_name).to start_with("mediconnect-#{appointment_id}-")
      end

      it "generates unique room names" do
        room_name1 = service.create_room(appointment_id)
        room_name2 = service.create_room(appointment_id)

        expect(room_name1).not_to eq(room_name2)
      end

      it "calls room service client with correct parameters" do
        expect(room_service_client).to receive(:create_room).with(
          hash_including(
            name: a_string_starting_with("mediconnect-#{appointment_id}-"),
            empty_timeout: 300,
            max_participants: 10
          )
        )

        service.create_room(appointment_id)
      end

      it "allows custom empty_timeout option" do
        expect(room_service_client).to receive(:create_room).with(
          hash_including(empty_timeout: 600)
        )

        service.create_room(appointment_id, empty_timeout: 600)
      end

      it "allows custom max_participants option" do
        expect(room_service_client).to receive(:create_room).with(
          hash_including(max_participants: 4)
        )

        service.create_room(appointment_id, max_participants: 4)
      end

      it "logs successful room creation" do
        expect(Rails.logger).to receive(:info).with(
          a_string_matching(/\[LiveKitService\] Successfully created room: mediconnect-/)
        )

        service.create_room(appointment_id)
      end
    end

    context "when room creation fails" do
      before do
        allow(room_service_client).to receive(:create_room).and_raise(StandardError.new("Connection failed"))
      end

      it "returns room name even on failure (graceful degradation)" do
        room_name = service.create_room(appointment_id)

        expect(room_name).to start_with("mediconnect-#{appointment_id}-")
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          "[LiveKitService] Failed to create room: Connection failed"
        )

        service.create_room(appointment_id)
      end
    end
  end

  describe "#generate_token" do
    let(:service) { described_class.new }
    let(:room_name) { "mediconnect-test-room" }
    let(:user_id) { "user-123" }
    let(:user_name) { "John Doe" }
    let(:mock_token) { double("AccessToken") }
    let(:mock_grant) { double("VideoGrant") }

    before do
      allow(LiveKit::AccessToken).to receive(:new).and_return(mock_token)
      allow(LiveKit::VideoGrant).to receive(:new).and_return(mock_grant)
      allow(mock_token).to receive(:video_grant=)
      allow(mock_token).to receive(:to_jwt).and_return("jwt_token_here")
    end

    it "creates an access token with correct credentials and identity" do
      expect(LiveKit::AccessToken).to receive(:new).with(
        api_key: api_key,
        api_secret: api_secret,
        identity: user_id.to_s,
        name: user_name,
        ttl: 4.hours.to_i
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)
    end

    it "sets default TTL to 4 hours in constructor" do
      expect(LiveKit::AccessToken).to receive(:new).with(
        hash_including(ttl: 4.hours.to_i)
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)
    end

    it "allows custom TTL" do
      custom_ttl = 2.hours.to_i
      expect(LiveKit::AccessToken).to receive(:new).with(
        hash_including(ttl: custom_ttl)
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name, ttl: custom_ttl)
    end

    it "passes identity to constructor" do
      expect(LiveKit::AccessToken).to receive(:new).with(
        hash_including(identity: user_id.to_s)
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)
    end

    it "passes name to constructor" do
      expect(LiveKit::AccessToken).to receive(:new).with(
        hash_including(name: user_name)
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)
    end

    it "creates video grant with correct room permissions" do
      expect(LiveKit::VideoGrant).to receive(:new).with(
        roomJoin: true,
        room: room_name,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        roomAdmin: false
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)
    end

    it "sets roomAdmin to true when is_owner is true" do
      expect(LiveKit::VideoGrant).to receive(:new).with(
        hash_including(roomAdmin: true)
      )

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name, is_owner: true)
    end

    it "assigns video grant to token" do
      expect(mock_token).to receive(:video_grant=).with(mock_grant)

      service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)
    end

    it "returns JWT token" do
      result = service.generate_token(room_name: room_name, user_id: user_id, user_name: user_name)

      expect(result).to eq("jwt_token_here")
    end

    it "converts numeric user_id to string" do
      expect(LiveKit::AccessToken).to receive(:new).with(
        hash_including(identity: "456")
      )

      service.generate_token(room_name: room_name, user_id: 456, user_name: user_name)
    end
  end

  describe "#delete_room" do
    let(:service) { described_class.new }
    let(:room_name) { "mediconnect-test-room" }
    let(:room_service_client) { double("RoomServiceClient") }

    before do
      allow(service).to receive(:room_service_client).and_return(room_service_client)
    end

    context "when deletion succeeds" do
      before do
        allow(room_service_client).to receive(:delete_room).and_return(true)
      end

      it "returns true" do
        expect(service.delete_room(room_name)).to be true
      end

      it "calls room service client with room name" do
        expect(room_service_client).to receive(:delete_room).with(room_name)

        service.delete_room(room_name)
      end

      it "logs successful deletion" do
        expect(Rails.logger).to receive(:info).with(
          "[LiveKitService] Successfully deleted room: #{room_name}"
        )

        service.delete_room(room_name)
      end
    end

    context "when deletion fails" do
      before do
        allow(room_service_client).to receive(:delete_room).and_raise(StandardError.new("Room not found"))
      end

      it "returns false" do
        expect(service.delete_room(room_name)).to be false
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          "[LiveKitService] Failed to delete room #{room_name}: Room not found"
        )

        service.delete_room(room_name)
      end
    end
  end

  describe "#get_room" do
    let(:service) { described_class.new }
    let(:room_name) { "mediconnect-test-room" }
    let(:room_service_client) { double("RoomServiceClient") }
    let(:mock_room) { double("LiveKit::Room", name: room_name) }

    before do
      allow(service).to receive(:room_service_client).and_return(room_service_client)
    end

    context "when room exists" do
      before do
        allow(room_service_client).to receive(:list_rooms).and_return([ mock_room ])
      end

      it "returns the room" do
        result = service.get_room(room_name)

        expect(result).to eq(mock_room)
      end

      it "calls list_rooms with the room name in an array" do
        expect(room_service_client).to receive(:list_rooms).with([ room_name ])

        service.get_room(room_name)
      end
    end

    context "when room does not exist" do
      before do
        allow(room_service_client).to receive(:list_rooms).and_return([])
      end

      it "returns nil" do
        expect(service.get_room(room_name)).to be_nil
      end
    end

    context "when an error occurs" do
      before do
        allow(room_service_client).to receive(:list_rooms).and_raise(StandardError.new("Connection error"))
      end

      it "returns nil" do
        expect(service.get_room(room_name)).to be_nil
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          "[LiveKitService] Failed to get room #{room_name}: Connection error"
        )

        service.get_room(room_name)
      end
    end
  end

  describe "#list_participants" do
    let(:service) { described_class.new }
    let(:room_name) { "mediconnect-test-room" }
    let(:room_service_client) { double("RoomServiceClient") }
    let(:participant1) { double("ParticipantInfo", identity: "user-1") }
    let(:participant2) { double("ParticipantInfo", identity: "user-2") }

    before do
      allow(service).to receive(:room_service_client).and_return(room_service_client)
    end

    context "when participants exist" do
      before do
        allow(room_service_client).to receive(:list_participants).and_return([ participant1, participant2 ])
      end

      it "returns array of participants" do
        result = service.list_participants(room_name)

        expect(result).to contain_exactly(participant1, participant2)
      end

      it "calls list_participants with room name" do
        expect(room_service_client).to receive(:list_participants).with(room_name)

        service.list_participants(room_name)
      end
    end

    context "when room is empty" do
      before do
        allow(room_service_client).to receive(:list_participants).and_return([])
      end

      it "returns empty array" do
        expect(service.list_participants(room_name)).to eq([])
      end
    end

    context "when an error occurs" do
      before do
        allow(room_service_client).to receive(:list_participants).and_raise(StandardError.new("Room not found"))
      end

      it "returns empty array" do
        expect(service.list_participants(room_name)).to eq([])
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          "[LiveKitService] Failed to list participants for room #{room_name}: Room not found"
        )

        service.list_participants(room_name)
      end
    end
  end

  describe "#remove_participant" do
    let(:service) { described_class.new }
    let(:room_name) { "mediconnect-test-room" }
    let(:identity) { "user-123" }
    let(:room_service_client) { double("RoomServiceClient") }

    before do
      allow(service).to receive(:room_service_client).and_return(room_service_client)
    end

    context "when removal succeeds" do
      before do
        allow(room_service_client).to receive(:remove_participant).and_return(true)
      end

      it "returns true" do
        expect(service.remove_participant(room_name, identity)).to be true
      end

      it "calls remove_participant with correct parameters" do
        expect(room_service_client).to receive(:remove_participant).with(room_name, identity)

        service.remove_participant(room_name, identity)
      end

      it "logs successful removal" do
        expect(Rails.logger).to receive(:info).with(
          "[LiveKitService] Removed participant #{identity} from room #{room_name}"
        )

        service.remove_participant(room_name, identity)
      end
    end

    context "when removal fails" do
      before do
        allow(room_service_client).to receive(:remove_participant).and_raise(StandardError.new("Participant not found"))
      end

      it "returns false" do
        expect(service.remove_participant(room_name, identity)).to be false
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          "[LiveKitService] Failed to remove participant #{identity} from room #{room_name}: Participant not found"
        )

        service.remove_participant(room_name, identity)
      end
    end
  end

  describe "#websocket_url" do
    it "returns the configured WebSocket URL" do
      service = described_class.new

      expect(service.websocket_url).to eq(ws_url)
    end
  end

  describe "#host_url" do
    it "returns the configured HTTP host URL" do
      service = described_class.new

      expect(service.host_url).to eq(host)
    end
  end

  describe "error classes" do
    it "defines Error as a subclass of StandardError" do
      expect(LiveKitService::Error.superclass).to eq(StandardError)
    end

    it "defines ConfigurationError as a subclass of Error" do
      expect(LiveKitService::ConfigurationError.superclass).to eq(LiveKitService::Error)
    end

    it "defines RoomCreationError as a subclass of Error" do
      expect(LiveKitService::RoomCreationError.superclass).to eq(LiveKitService::Error)
    end
  end
end
