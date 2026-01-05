import { useState, useCallback, useEffect } from "react";
import {
  LiveKitRoom,
  RoomAudioRenderer,
  useParticipants,
  useTracks,
  useRoomContext,
  useConnectionState,
} from "@livekit/components-react";
import { RoomEvent, ConnectionState, Track } from "livekit-client";
import type { Room } from "livekit-client";
import { cn } from "~/lib/utils";
import { VideoParticipant } from "./VideoParticipant";
import { VideoControls } from "./VideoControls";
import { ConnectionStatus } from "./ConnectionStatus";
import { VideoSessionStatus } from "~/features/video/types";

/**
 * Props for the VideoRoom component.
 */
export interface VideoRoomProps {
  /** LiveKit server URL */
  serverUrl: string;
  /** LiveKit access token */
  token: string;
  /** Callback when user leaves the room */
  onLeave: () => void;
  /** Callback when connection state changes */
  onConnectionStateChange?: (state: VideoSessionStatus) => void;
  /** Callback when an error occurs */
  onError?: (error: Error) => void;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Map LiveKit ConnectionState to VideoSessionStatus.
 */
function mapConnectionState(state: ConnectionState): VideoSessionStatus {
  switch (state) {
    case ConnectionState.Connecting:
      return VideoSessionStatus.CONNECTING;
    case ConnectionState.Connected:
      return VideoSessionStatus.CONNECTED;
    case ConnectionState.Disconnected:
      return VideoSessionStatus.DISCONNECTED;
    case ConnectionState.Reconnecting:
      return VideoSessionStatus.CONNECTING;
    default:
      return VideoSessionStatus.WAITING;
  }
}

/**
 * Inner component that uses LiveKit hooks (must be inside LiveKitRoom).
 */
interface VideoRoomInnerProps {
  onLeave: () => void;
  onConnectionStateChange?: (state: VideoSessionStatus) => void;
  onError?: (error: Error) => void;
}

function VideoRoomInner({
  onLeave,
  onConnectionStateChange,
  onError,
}: VideoRoomInnerProps) {
  const [connectionStatus, setConnectionStatus] = useState<VideoSessionStatus>(
    VideoSessionStatus.CONNECTING
  );
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Get room context
  const room = useRoomContext();

  // Get connection state
  const connectionState = useConnectionState();

  // Get all participants
  const participants = useParticipants();

  // Get local participant
  const localParticipant = room?.localParticipant;

  // Get remote participants (exclude local)
  const remoteParticipants = participants.filter(
    (p) => p.identity !== localParticipant?.identity
  );

  // Get screen share tracks
  const screenShareTracks = useTracks([Track.Source.ScreenShare]);
  const screenShareTrack = screenShareTracks[0];

  // Update connection status when LiveKit state changes
  useEffect(() => {
    const status = mapConnectionState(connectionState);
    setConnectionStatus(status);
    onConnectionStateChange?.(status);

    if (connectionState === ConnectionState.Disconnected) {
      setErrorMessage("Connection lost. Please try rejoining.");
    } else {
      setErrorMessage(null);
    }
  }, [connectionState, onConnectionStateChange]);

  // Handle room events
  useEffect(() => {
    if (!room) return;

    const handleDisconnected = () => {
      setConnectionStatus(VideoSessionStatus.DISCONNECTED);
      onConnectionStateChange?.(VideoSessionStatus.DISCONNECTED);
    };

    const handleReconnecting = () => {
      setConnectionStatus(VideoSessionStatus.CONNECTING);
      onConnectionStateChange?.(VideoSessionStatus.CONNECTING);
    };

    const handleReconnected = () => {
      setConnectionStatus(VideoSessionStatus.CONNECTED);
      onConnectionStateChange?.(VideoSessionStatus.CONNECTED);
      setErrorMessage(null);
    };

    const handleError = (error: Error) => {
      console.error("Room error:", error);
      setConnectionStatus(VideoSessionStatus.ERROR);
      setErrorMessage(error.message || "An error occurred");
      onConnectionStateChange?.(VideoSessionStatus.ERROR);
      onError?.(error);
    };

    room.on(RoomEvent.Disconnected, handleDisconnected);
    room.on(RoomEvent.Reconnecting, handleReconnecting);
    room.on(RoomEvent.Reconnected, handleReconnected);
    room.on(RoomEvent.MediaDevicesError, handleError);
    room.on(RoomEvent.ConnectionQualityChanged, (quality, participant) => {
      // Could track quality here for UI updates
    });

    return () => {
      room.off(RoomEvent.Disconnected, handleDisconnected);
      room.off(RoomEvent.Reconnecting, handleReconnecting);
      room.off(RoomEvent.Reconnected, handleReconnected);
      room.off(RoomEvent.MediaDevicesError, handleError);
    };
  }, [room, onConnectionStateChange, onError]);

  // Handle leave
  const handleLeave = useCallback(async () => {
    try {
      await room?.disconnect();
    } catch (err) {
      console.error("Error disconnecting:", err);
    }
    onLeave();
  }, [room, onLeave]);

  // Determine layout based on participant count and screen share
  const hasScreenShare = !!screenShareTrack;
  const participantCount = participants.length;

  return (
    <div className="flex flex-col h-full bg-gray-950">
      {/* Error Banner */}
      {errorMessage && connectionStatus === VideoSessionStatus.ERROR && (
        <div
          className={cn(
            "px-4 py-3",
            "bg-red-600 text-white",
            "text-center text-sm"
          )}
          role="alert"
        >
          {errorMessage}
        </div>
      )}

      {/* Reconnecting Banner */}
      {connectionStatus === VideoSessionStatus.CONNECTING && (
        <div
          className={cn(
            "px-4 py-2",
            "bg-yellow-500 text-yellow-900",
            "text-center text-sm",
            "flex items-center justify-center gap-2"
          )}
          role="status"
        >
          <svg
            className="animate-spin h-4 w-4"
            viewBox="0 0 24 24"
            fill="none"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
          <span>Reconnecting...</span>
        </div>
      )}

      {/* Video Grid */}
      <div className="flex-1 p-2 sm:p-4 overflow-hidden">
        {hasScreenShare ? (
          // Screen share layout: main screen share + sidebar with participants
          <div className="h-full flex flex-col lg:flex-row gap-2 sm:gap-4">
            {/* Main screen share view */}
            <div className="flex-1 min-h-0">
              {screenShareTrack && (
                <VideoParticipant
                  participant={screenShareTrack.participant}
                  isLarge
                  className="w-full h-full"
                />
              )}
            </div>
            {/* Participants sidebar */}
            <div className="lg:w-64 flex lg:flex-col gap-2 overflow-auto">
              {localParticipant && (
                <VideoParticipant
                  participant={localParticipant}
                  isLocal
                  className="w-32 lg:w-full flex-shrink-0"
                />
              )}
              {remoteParticipants.map((participant) => (
                <VideoParticipant
                  key={participant.identity}
                  participant={participant}
                  className="w-32 lg:w-full flex-shrink-0"
                />
              ))}
            </div>
          </div>
        ) : participantCount === 1 ? (
          // Single participant (just local)
          <div className="h-full flex items-center justify-center">
            <div className="w-full max-w-3xl">
              {localParticipant && (
                <VideoParticipant
                  participant={localParticipant}
                  isLocal
                  isLarge
                  className="w-full"
                />
              )}
              <p className="text-center text-gray-400 mt-4">
                Waiting for other participants to join...
              </p>
            </div>
          </div>
        ) : participantCount === 2 ? (
          // Two participants: side by side on desktop, stacked on mobile
          <div className="h-full flex flex-col sm:flex-row gap-2 sm:gap-4">
            {remoteParticipants[0] && (
              <VideoParticipant
                participant={remoteParticipants[0]}
                isLarge
                className="flex-1 min-h-0"
              />
            )}
            {localParticipant && (
              <VideoParticipant
                participant={localParticipant}
                isLocal
                className="w-full sm:w-48 lg:w-64 h-32 sm:h-auto sm:absolute sm:bottom-24 sm:right-6 sm:z-10"
              />
            )}
          </div>
        ) : (
          // Multiple participants: grid layout
          <div
            className={cn(
              "h-full grid gap-2 sm:gap-4 auto-rows-fr",
              participantCount <= 4
                ? "grid-cols-1 sm:grid-cols-2"
                : participantCount <= 6
                ? "grid-cols-2 sm:grid-cols-3"
                : "grid-cols-2 sm:grid-cols-3 lg:grid-cols-4"
            )}
          >
            {localParticipant && (
              <VideoParticipant
                participant={localParticipant}
                isLocal
                className="w-full h-full"
              />
            )}
            {remoteParticipants.map((participant) => (
              <VideoParticipant
                key={participant.identity}
                participant={participant}
                className="w-full h-full"
              />
            ))}
          </div>
        )}
      </div>

      {/* Audio Renderer (handles audio for all participants) */}
      <RoomAudioRenderer />

      {/* Controls */}
      <div className="flex-shrink-0 p-4 flex justify-center">
        <VideoControls
          onLeave={handleLeave}
          connectionStatus={connectionStatus}
        />
      </div>
    </div>
  );
}

/**
 * VideoRoom Component
 *
 * Main video room component that wraps the LiveKit room and provides
 * the video consultation UI.
 *
 * Features:
 * - LiveKit room connection with token authentication
 * - Automatic reconnection handling
 * - Dynamic participant grid layout
 * - Screen share support with layout adaptation
 * - Connection state management
 * - Error handling and display
 * - Audio rendering for all participants
 * - Responsive design for mobile and desktop
 *
 * @example
 * <VideoRoom
 *   serverUrl="wss://livekit.example.com"
 *   token="eyJ..."
 *   onLeave={handleLeave}
 *   onError={handleError}
 * />
 */
export function VideoRoom({
  serverUrl,
  token,
  onLeave,
  onConnectionStateChange,
  onError,
  className,
}: VideoRoomProps) {
  const [connectionError, setConnectionError] = useState<Error | null>(null);

  const handleError = useCallback(
    (error: Error) => {
      console.error("VideoRoom error:", error);
      setConnectionError(error);
      onError?.(error);
    },
    [onError]
  );

  // Handle connection errors from LiveKitRoom
  const handleRoomError = useCallback((error: Error) => {
    console.error("LiveKitRoom connection error:", error);
    setConnectionError(error);
    onConnectionStateChange?.(VideoSessionStatus.ERROR);
    onError?.(error);
  }, [onConnectionStateChange, onError]);

  if (connectionError) {
    return (
      <div
        className={cn(
          "min-h-screen bg-gray-950",
          "flex items-center justify-center",
          "p-4",
          className
        )}
      >
        <div
          className={cn(
            "max-w-md w-full",
            "bg-gray-900 rounded-xl p-6",
            "text-center"
          )}
        >
          <div
            className={cn(
              "w-16 h-16 mx-auto mb-4 rounded-full",
              "bg-red-900/30 flex items-center justify-center"
            )}
          >
            <svg
              className="w-8 h-8 text-red-500"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <circle cx="12" cy="12" r="10" />
              <line x1="15" y1="9" x2="9" y2="15" />
              <line x1="9" y1="9" x2="15" y2="15" />
            </svg>
          </div>
          <h2 className="text-xl font-semibold text-white mb-2">
            Connection Failed
          </h2>
          <p className="text-gray-400 mb-6">
            {connectionError.message ||
              "Unable to connect to the video consultation. Please try again."}
          </p>
          <div className="flex gap-3 justify-center">
            <button
              onClick={() => setConnectionError(null)}
              className={cn(
                "px-4 py-2 rounded-lg",
                "bg-primary-600 text-white",
                "hover:bg-primary-700",
                "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500"
              )}
            >
              Try Again
            </button>
            <button
              onClick={onLeave}
              className={cn(
                "px-4 py-2 rounded-lg",
                "bg-gray-700 text-white",
                "hover:bg-gray-600",
                "focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-500"
              )}
            >
              Go Back
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <LiveKitRoom
      serverUrl={serverUrl}
      token={token}
      connect={true}
      audio={true}
      video={true}
      onError={handleRoomError}
      className={cn("h-screen", className)}
      data-lk-theme="default"
    >
      <VideoRoomInner
        onLeave={onLeave}
        onConnectionStateChange={onConnectionStateChange}
        onError={handleError}
      />
    </LiveKitRoom>
  );
}