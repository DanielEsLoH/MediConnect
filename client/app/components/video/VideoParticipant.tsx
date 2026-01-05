import { useRef } from "react";
import type { Participant } from "livekit-client";
import { Track } from "livekit-client";
import {
  useTracks,
  useIsSpeaking,
  useIsMuted,
  VideoTrack,
  AudioTrack,
  isTrackReference,
} from "@livekit/components-react";
import type { TrackReferenceOrPlaceholder } from "@livekit/components-react";
import { cn } from "~/lib/utils";

/**
 * Props for the VideoParticipant component.
 */
export interface VideoParticipantProps {
  /** The LiveKit participant object */
  participant: Participant;
  /** Whether this is the local participant */
  isLocal?: boolean;
  /** Whether to show the participant in a large view */
  isLarge?: boolean;
  /** Additional CSS classes */
  className?: string;
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
 * Speaking indicator icon.
 */
function SpeakingIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z" />
      <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z" />
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
 * Get initials from a name for avatar fallback.
 */
function getInitials(name: string): string {
  return name
    .split(" ")
    .map((part) => part[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

/**
 * VideoParticipant Component
 *
 * Displays a single participant's video tile with video/audio tracks,
 * name overlay, and status indicators.
 *
 * Features:
 * - Video track display with LiveKit's VideoTrack component
 * - Audio track handling
 * - Muted indicator when microphone is off
 * - Speaking indicator when participant is actively speaking
 * - Screen share indicator
 * - Avatar fallback when camera is off
 * - Name overlay with identity
 * - Responsive sizing
 * - Accessibility support
 *
 * @example
 * <VideoParticipant participant={participant} isLocal />
 * <VideoParticipant participant={participant} isLarge />
 */
export function VideoParticipant({
  participant,
  isLocal = false,
  isLarge = false,
  className,
}: VideoParticipantProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  // Get speaking state using LiveKit hook
  const isSpeaking = useIsSpeaking(participant);

  // Get tracks for this specific participant using filter
  const allTracks = useTracks(
    [
      { source: Track.Source.Camera, withPlaceholder: true },
      { source: Track.Source.Microphone, withPlaceholder: false },
      { source: Track.Source.ScreenShare, withPlaceholder: false },
    ]
  );

  // Filter tracks for this participant
  const participantTracks = allTracks.filter(
    (track) => track.participant.identity === participant.identity
  );

  const cameraTrack = participantTracks.find(
    (track) => track.source === Track.Source.Camera
  );
  const micTrack = participantTracks.find(
    (track) => track.source === Track.Source.Microphone
  );
  const screenShareTrack = participantTracks.find(
    (track) => track.source === Track.Source.ScreenShare
  );

  // Check muted state using the track reference
  const isMicMuted = useIsMuted(micTrack as TrackReferenceOrPlaceholder);

  // Get display name from participant identity or metadata
  const displayName =
    participant.name || participant.identity || "Unknown Participant";

  // Check if camera is enabled
  const isCameraEnabled = cameraTrack?.publication?.track && !cameraTrack.publication.isMuted;
  const isScreenSharing = !!screenShareTrack?.publication?.track;

  // Determine which video track to show (screen share takes priority)
  const activeVideoTrack = isScreenSharing ? screenShareTrack : cameraTrack;
  const hasVideo = !!activeVideoTrack?.publication?.track;

  return (
    <div
      ref={containerRef}
      className={cn(
        "relative overflow-hidden rounded-lg",
        "bg-gray-900",
        isLarge ? "aspect-video" : "aspect-video sm:aspect-[4/3]",
        isSpeaking && "ring-2 ring-green-500 ring-offset-2 ring-offset-gray-900",
        className
      )}
      role="region"
      aria-label={`Video of ${displayName}${isLocal ? " (You)" : ""}`}
    >
      {/* Video Track or Avatar Fallback */}
      {hasVideo && activeVideoTrack && isTrackReference(activeVideoTrack) ? (
        <VideoTrack
          trackRef={activeVideoTrack}
          className="absolute inset-0 w-full h-full object-cover"
        />
      ) : (
        <div className="absolute inset-0 flex items-center justify-center bg-gray-800">
          <div
            className={cn(
              "flex items-center justify-center rounded-full bg-primary-600",
              isLarge ? "w-24 h-24" : "w-16 h-16 sm:w-20 sm:h-20"
            )}
          >
            <span
              className={cn(
                "font-semibold text-white",
                isLarge ? "text-3xl" : "text-xl sm:text-2xl"
              )}
            >
              {getInitials(displayName)}
            </span>
          </div>
        </div>
      )}

      {/* Audio Track (hidden, just for playback) */}
      {micTrack && isTrackReference(micTrack) && !isLocal && (
        <AudioTrack trackRef={micTrack} />
      )}

      {/* Name Overlay */}
      <div
        className={cn(
          "absolute bottom-0 left-0 right-0",
          "bg-gradient-to-t from-black/70 to-transparent",
          "px-3 py-2"
        )}
      >
        <div className="flex items-center justify-between">
          <span className="text-white text-sm font-medium truncate">
            {displayName}
            {isLocal && (
              <span className="ml-1 text-xs text-gray-300">(You)</span>
            )}
          </span>

          {/* Status Indicators */}
          <div className="flex items-center gap-2">
            {/* Screen share indicator */}
            {isScreenSharing && (
              <span
                className="text-blue-400"
                title="Sharing screen"
              >
                <ScreenShareIcon className="w-4 h-4" />
              </span>
            )}

            {/* Speaking indicator */}
            {isSpeaking && (
              <span
                className="text-green-400 animate-pulse"
                title="Speaking"
              >
                <SpeakingIcon className="w-4 h-4" />
              </span>
            )}

            {/* Muted indicator */}
            {isMicMuted && (
              <span
                className="text-red-400"
                title="Microphone muted"
              >
                <MicMutedIcon className="w-4 h-4" />
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Camera Off Overlay */}
      {!isCameraEnabled && !isScreenSharing && (
        <div className="absolute top-2 left-2">
          <span
            className={cn(
              "inline-flex items-center gap-1 px-2 py-1 rounded",
              "bg-black/50 text-white text-xs"
            )}
          >
            Camera off
          </span>
        </div>
      )}

      {/* Local indicator badge */}
      {isLocal && (
        <div className="absolute top-2 right-2">
          <span
            className={cn(
              "inline-block px-2 py-0.5 rounded text-xs",
              "bg-primary-600 text-white"
            )}
          >
            You
          </span>
        </div>
      )}
    </div>
  );
}