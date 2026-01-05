import { useState, useCallback } from "react";
import {
  useLocalParticipant,
  useRoomContext,
  usePersistentUserChoices,
} from "@livekit/components-react";
import { RoomEvent } from "livekit-client";
import { cn } from "~/lib/utils";
import { ConnectionStatus } from "./ConnectionStatus";
import { VideoSessionStatus } from "~/features/video/types";

/**
 * Props for the VideoControls component.
 */
export interface VideoControlsProps {
  /** Callback when user leaves the call */
  onLeave: () => void;
  /** Current connection status */
  connectionStatus: VideoSessionStatus;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Microphone icon.
 */
function MicIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
      <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  );
}

/**
 * Microphone muted icon.
 */
function MicMutedIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <line x1="1" y1="1" x2="23" y2="23" />
      <path d="M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V4a3 3 0 0 0-5.94-.6" />
      <path d="M17 16.95A7 7 0 0 1 5 12v-2m14 0v2a7 7 0 0 1-.11 1.23" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  );
}

/**
 * Camera icon.
 */
function CameraIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <polygon points="23 7 16 12 23 17 23 7" />
      <rect x="1" y="5" width="15" height="14" rx="2" ry="2" />
    </svg>
  );
}

/**
 * Camera off icon.
 */
function CameraOffIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <line x1="1" y1="1" x2="23" y2="23" />
      <path d="M21 21H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3m3-3h6l2 3h4a2 2 0 0 1 2 2v9.34m-7.72-2.06a4 4 0 1 1-5.56-5.56" />
    </svg>
  );
}

/**
 * Screen share icon.
 */
function ScreenShareIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
      <line x1="8" y1="21" x2="16" y2="21" />
      <line x1="12" y1="17" x2="12" y2="21" />
    </svg>
  );
}

/**
 * Screen share off icon.
 */
function ScreenShareOffIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <line x1="1" y1="1" x2="23" y2="23" />
      <path d="M22 17H2a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h20a2 2 0 0 1 2 2v10" />
      <line x1="8" y1="21" x2="16" y2="21" />
      <line x1="12" y1="17" x2="12" y2="21" />
    </svg>
  );
}

/**
 * Phone off icon for leaving call.
 */
function PhoneOffIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M10.68 13.31a16 16 0 0 0 3.41 2.6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7 2 2 0 0 1 1.72 2v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.42 19.42 0 0 1-3.33-2.67m-2.67-3.34a19.79 19.79 0 0 1-3.07-8.63A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91" />
      <line x1="23" y1="1" x2="1" y2="23" />
    </svg>
  );
}

/**
 * VideoControls Component
 *
 * Control bar for video consultation with buttons to toggle microphone,
 * camera, screen share, and leave the call.
 *
 * Features:
 * - Microphone mute/unmute toggle
 * - Camera on/off toggle
 * - Screen share toggle
 * - Leave call button with confirmation
 * - Connection status indicator
 * - Keyboard accessible
 * - Responsive design
 *
 * Uses LiveKit hooks:
 * - useLocalParticipant for local track states
 * - useRoomContext for room actions
 *
 * @example
 * <VideoControls
 *   onLeave={handleLeave}
 *   connectionStatus={VideoSessionStatus.CONNECTED}
 * />
 */
export function VideoControls({
  onLeave,
  connectionStatus,
  className,
}: VideoControlsProps) {
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false);
  const [isTogglingMic, setIsTogglingMic] = useState(false);
  const [isTogglingCamera, setIsTogglingCamera] = useState(false);
  const [isTogglingScreenShare, setIsTogglingScreenShare] = useState(false);

  // Get local participant state
  const { localParticipant, isMicrophoneEnabled, isCameraEnabled, isScreenShareEnabled } =
    useLocalParticipant();

  // Get room context for actions
  const room = useRoomContext();

  /**
   * Toggle microphone on/off.
   */
  const handleToggleMic = useCallback(async () => {
    if (isTogglingMic || !localParticipant) return;

    setIsTogglingMic(true);
    try {
      await localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled);
    } catch (error) {
      console.error("Failed to toggle microphone:", error);
    } finally {
      setIsTogglingMic(false);
    }
  }, [localParticipant, isMicrophoneEnabled, isTogglingMic]);

  /**
   * Toggle camera on/off.
   */
  const handleToggleCamera = useCallback(async () => {
    if (isTogglingCamera || !localParticipant) return;

    setIsTogglingCamera(true);
    try {
      await localParticipant.setCameraEnabled(!isCameraEnabled);
    } catch (error) {
      console.error("Failed to toggle camera:", error);
    } finally {
      setIsTogglingCamera(false);
    }
  }, [localParticipant, isCameraEnabled, isTogglingCamera]);

  /**
   * Toggle screen share on/off.
   */
  const handleToggleScreenShare = useCallback(async () => {
    if (isTogglingScreenShare || !localParticipant) return;

    setIsTogglingScreenShare(true);
    try {
      await localParticipant.setScreenShareEnabled(!isScreenShareEnabled);
    } catch (error) {
      console.error("Failed to toggle screen share:", error);
    } finally {
      setIsTogglingScreenShare(false);
    }
  }, [localParticipant, isScreenShareEnabled, isTogglingScreenShare]);

  /**
   * Handle leave button click.
   */
  const handleLeaveClick = useCallback(() => {
    setShowLeaveConfirm(true);
  }, []);

  /**
   * Confirm leaving the call.
   */
  const handleConfirmLeave = useCallback(() => {
    setShowLeaveConfirm(false);
    onLeave();
  }, [onLeave]);

  /**
   * Cancel leave confirmation.
   */
  const handleCancelLeave = useCallback(() => {
    setShowLeaveConfirm(false);
  }, []);

  return (
    <div className={cn("relative", className)}>
      {/* Control Bar */}
      <div
        className={cn(
          "flex items-center justify-center gap-2 sm:gap-4",
          "px-4 py-3 sm:px-6 sm:py-4",
          "bg-gray-900/95 backdrop-blur-sm",
          "rounded-xl shadow-lg"
        )}
        role="toolbar"
        aria-label="Video call controls"
      >
        {/* Connection Status */}
        <ConnectionStatus status={connectionStatus} compact className="mr-2" />

        {/* Microphone Toggle */}
        <button
          type="button"
          onClick={handleToggleMic}
          disabled={isTogglingMic}
          className={cn(
            "p-3 sm:p-4 rounded-full transition-colors",
            "focus:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-gray-900",
            "disabled:opacity-50 disabled:cursor-not-allowed",
            isMicrophoneEnabled
              ? "bg-gray-700 hover:bg-gray-600 text-white"
              : "bg-red-600 hover:bg-red-700 text-white"
          )}
          aria-label={isMicrophoneEnabled ? "Mute microphone" : "Unmute microphone"}
          aria-pressed={!isMicrophoneEnabled}
        >
          {isMicrophoneEnabled ? (
            <MicIcon className="w-5 h-5 sm:w-6 sm:h-6" />
          ) : (
            <MicMutedIcon className="w-5 h-5 sm:w-6 sm:h-6" />
          )}
        </button>

        {/* Camera Toggle */}
        <button
          type="button"
          onClick={handleToggleCamera}
          disabled={isTogglingCamera}
          className={cn(
            "p-3 sm:p-4 rounded-full transition-colors",
            "focus:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-gray-900",
            "disabled:opacity-50 disabled:cursor-not-allowed",
            isCameraEnabled
              ? "bg-gray-700 hover:bg-gray-600 text-white"
              : "bg-red-600 hover:bg-red-700 text-white"
          )}
          aria-label={isCameraEnabled ? "Turn off camera" : "Turn on camera"}
          aria-pressed={!isCameraEnabled}
        >
          {isCameraEnabled ? (
            <CameraIcon className="w-5 h-5 sm:w-6 sm:h-6" />
          ) : (
            <CameraOffIcon className="w-5 h-5 sm:w-6 sm:h-6" />
          )}
        </button>

        {/* Screen Share Toggle */}
        <button
          type="button"
          onClick={handleToggleScreenShare}
          disabled={isTogglingScreenShare}
          className={cn(
            "hidden sm:block", // Hide on mobile
            "p-3 sm:p-4 rounded-full transition-colors",
            "focus:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-gray-900",
            "disabled:opacity-50 disabled:cursor-not-allowed",
            isScreenShareEnabled
              ? "bg-blue-600 hover:bg-blue-700 text-white"
              : "bg-gray-700 hover:bg-gray-600 text-white"
          )}
          aria-label={isScreenShareEnabled ? "Stop sharing screen" : "Share screen"}
          aria-pressed={isScreenShareEnabled}
        >
          {isScreenShareEnabled ? (
            <ScreenShareOffIcon className="w-5 h-5 sm:w-6 sm:h-6" />
          ) : (
            <ScreenShareIcon className="w-5 h-5 sm:w-6 sm:h-6" />
          )}
        </button>

        {/* Divider */}
        <div className="w-px h-8 bg-gray-700 mx-1 sm:mx-2" aria-hidden="true" />

        {/* Leave Call Button */}
        <button
          type="button"
          onClick={handleLeaveClick}
          className={cn(
            "p-3 sm:p-4 rounded-full transition-colors",
            "bg-red-600 hover:bg-red-700 text-white",
            "focus:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-gray-900"
          )}
          aria-label="Leave call"
        >
          <PhoneOffIcon className="w-5 h-5 sm:w-6 sm:h-6" />
        </button>
      </div>

      {/* Leave Confirmation Modal */}
      {showLeaveConfirm && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="leave-dialog-title"
        >
          <div
            className={cn(
              "bg-white dark:bg-gray-900",
              "rounded-lg shadow-xl",
              "p-6 mx-4 max-w-sm w-full"
            )}
          >
            <h2
              id="leave-dialog-title"
              className="text-lg font-semibold text-gray-900 dark:text-gray-100"
            >
              Leave Video Call?
            </h2>
            <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
              Are you sure you want to leave this video consultation? You can
              rejoin later if the session is still active.
            </p>
            <div className="mt-4 flex gap-3 justify-end">
              <button
                type="button"
                onClick={handleCancelLeave}
                className={cn(
                  "px-4 py-2 rounded-lg",
                  "text-gray-700 dark:text-gray-300",
                  "bg-gray-100 dark:bg-gray-800",
                  "hover:bg-gray-200 dark:hover:bg-gray-700",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500"
                )}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmLeave}
                className={cn(
                  "px-4 py-2 rounded-lg",
                  "text-white bg-red-600",
                  "hover:bg-red-700",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-red-500"
                )}
              >
                Leave Call
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}