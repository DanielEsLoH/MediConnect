import { useState, useCallback, useEffect } from "react";
import { useParams, useNavigate, Link } from "react-router";
import { useQuery, useMutation } from "@tanstack/react-query";
import type { LocalUserChoices } from "@livekit/components-react";

import { cn } from "~/lib/utils";
import { Spinner, Button } from "~/components/ui";
import { ProtectedRoute } from "~/components/ProtectedRoute";
import { VideoRoom, WaitingRoom } from "~/components/video";
import { videoApi } from "~/features/video";
import { VideoSessionStatus, type AppointmentInfo } from "~/features/video/types";

/**
 * Video session state.
 */
type VideoState = "loading" | "waiting" | "joining" | "in_call" | "ended" | "error";

/**
 * Error state component.
 */
interface ErrorStateProps {
  title: string;
  message: string;
  onRetry?: () => void;
  showHomeLink?: boolean;
}

function ErrorState({ title, message, onRetry, showHomeLink = true }: ErrorStateProps) {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center p-4">
      <div className="max-w-md w-full text-center">
        <div
          className={cn(
            "w-16 h-16 mx-auto mb-4 rounded-full",
            "bg-red-100 dark:bg-red-900/30",
            "flex items-center justify-center"
          )}
        >
          <svg
            className="w-8 h-8 text-red-600 dark:text-red-400"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
        </div>
        <h1 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-2">
          {title}
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mb-6">{message}</p>
        <div className="flex gap-3 justify-center">
          {onRetry && (
            <Button variant="primary" onClick={onRetry}>
              Try Again
            </Button>
          )}
          {showHomeLink && (
            <Link
              to="/appointments"
              className={cn(
                "inline-flex items-center justify-center",
                "px-4 py-2 rounded-lg",
                "border border-gray-300 dark:border-gray-700",
                "text-gray-700 dark:text-gray-300",
                "hover:bg-gray-50 dark:hover:bg-gray-800",
                "transition-colors"
              )}
            >
              Back to Appointments
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * Loading state component.
 */
function LoadingState() {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center">
      <div className="text-center">
        <Spinner size="lg" center />
        <p className="mt-4 text-gray-600 dark:text-gray-400">
          Loading video consultation...
        </p>
      </div>
    </div>
  );
}

/**
 * Call ended state component.
 */
function CallEndedState() {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center p-4">
      <div className="max-w-md w-full text-center">
        <div
          className={cn(
            "w-16 h-16 mx-auto mb-4 rounded-full",
            "bg-green-100 dark:bg-green-900/30",
            "flex items-center justify-center"
          )}
        >
          <svg
            className="w-8 h-8 text-green-600 dark:text-green-400"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>
        <h1 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-2">
          Consultation Ended
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mb-6">
          Thank you for using MediConnect video consultation. We hope your
          appointment was helpful.
        </p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link
            to="/appointments"
            className={cn(
              "inline-flex items-center justify-center",
              "px-4 py-2 rounded-lg",
              "bg-primary-600 text-white",
              "hover:bg-primary-700",
              "transition-colors"
            )}
          >
            Back to Appointments
          </Link>
          <Link
            to="/dashboard"
            className={cn(
              "inline-flex items-center justify-center",
              "px-4 py-2 rounded-lg",
              "border border-gray-300 dark:border-gray-700",
              "text-gray-700 dark:text-gray-300",
              "hover:bg-gray-50 dark:hover:bg-gray-800",
              "transition-colors"
            )}
          >
            Go to Dashboard
          </Link>
        </div>
      </div>
    </div>
  );
}

/**
 * Video Consultation Page Content
 *
 * Inner component that handles the video consultation flow.
 */
function VideoConsultationContent() {
  const { id: appointmentId } = useParams();
  const navigate = useNavigate();

  const [videoState, setVideoState] = useState<VideoState>("loading");
  const [connectionStatus, setConnectionStatus] = useState<VideoSessionStatus>(
    VideoSessionStatus.WAITING
  );
  const [joinError, setJoinError] = useState<string | null>(null);
  const [videoToken, setVideoToken] = useState<string | null>(null);
  const [serverUrl, setServerUrl] = useState<string | null>(null);

  // Fetch video session details
  const {
    data: sessionData,
    isLoading: isLoadingSession,
    isError: isSessionError,
    error: sessionError,
    refetch: refetchSession,
  } = useQuery({
    queryKey: ["video-session", appointmentId],
    queryFn: () => videoApi.getVideoSession(appointmentId!),
    enabled: !!appointmentId,
    retry: 1,
    staleTime: 0, // Always fetch fresh data
  });

  // Get video token mutation
  const getTokenMutation = useMutation({
    mutationFn: () => videoApi.getVideoToken(appointmentId!),
    onSuccess: (data) => {
      setVideoToken(data.token);
      setServerUrl(data.server_url);
      setVideoState("in_call");
      setJoinError(null);
    },
    onError: (error: Error) => {
      console.error("Failed to get video token:", error);
      setJoinError(error.message || "Failed to join video consultation");
      setVideoState("error");
    },
  });

  // End session mutation
  const endSessionMutation = useMutation({
    mutationFn: () => videoApi.endVideoSession(appointmentId!),
    onSuccess: () => {
      setVideoState("ended");
    },
    onError: (error) => {
      console.error("Failed to end session:", error);
      // Still navigate away even if end fails
      setVideoState("ended");
    },
  });

  // Update state based on session data
  useEffect(() => {
    if (isLoadingSession) {
      setVideoState("loading");
    } else if (isSessionError) {
      setVideoState("error");
    } else if (sessionData) {
      setVideoState("waiting");
    }
  }, [isLoadingSession, isSessionError, sessionData]);

  /**
   * Handle joining the video call from waiting room.
   */
  const handleJoin = useCallback(
    (userChoices: LocalUserChoices) => {
      setVideoState("joining");
      getTokenMutation.mutate();
    },
    [getTokenMutation]
  );

  /**
   * Handle leaving the video call.
   */
  const handleLeave = useCallback(() => {
    endSessionMutation.mutate();
  }, [endSessionMutation]);

  /**
   * Handle connection state changes.
   */
  const handleConnectionStateChange = useCallback((state: VideoSessionStatus) => {
    setConnectionStatus(state);
  }, []);

  /**
   * Handle video room errors.
   */
  const handleVideoError = useCallback((error: Error) => {
    console.error("Video room error:", error);
    setJoinError(error.message);
    setVideoState("error");
  }, []);

  // Mock appointment info - in production this would come from session data
  const appointmentInfo: AppointmentInfo = sessionData?.metadata
    ? {
        doctorName: sessionData.metadata.doctor_name,
        doctorSpecialty: sessionData.metadata.doctor_specialty,
        scheduledTime: sessionData.metadata.scheduled_time,
        durationMinutes: sessionData.metadata.duration_minutes,
      }
    : {
        doctorName: "Dr. Sarah Chen",
        doctorSpecialty: "General Medicine",
        scheduledTime: new Date().toISOString(),
        durationMinutes: 30,
      };

  // Invalid appointment ID
  if (!appointmentId) {
    return (
      <ErrorState
        title="Invalid Appointment"
        message="No appointment ID was provided. Please select an appointment from your appointments list."
      />
    );
  }

  // Loading state
  if (videoState === "loading") {
    return <LoadingState />;
  }

  // Error state
  if (videoState === "error") {
    const errorMessage =
      joinError ||
      (sessionError instanceof Error
        ? sessionError.message
        : "Failed to load video consultation. Please try again.");

    return (
      <ErrorState
        title="Unable to Load"
        message={errorMessage}
        onRetry={() => {
          setJoinError(null);
          refetchSession();
        }}
      />
    );
  }

  // Call ended state
  if (videoState === "ended") {
    return <CallEndedState />;
  }

  // Waiting room (pre-join)
  if (videoState === "waiting" || videoState === "joining") {
    return (
      <WaitingRoom
        appointmentInfo={appointmentInfo}
        onJoin={handleJoin}
        isJoining={videoState === "joining" || getTokenMutation.isPending}
        error={joinError || undefined}
      />
    );
  }

  // In call state
  if (videoState === "in_call" && videoToken && serverUrl) {
    return (
      <VideoRoom
        serverUrl={serverUrl}
        token={videoToken}
        onLeave={handleLeave}
        onConnectionStateChange={handleConnectionStateChange}
        onError={handleVideoError}
      />
    );
  }

  // Fallback loading
  return <LoadingState />;
}

/**
 * Video Consultation Page
 *
 * Route component for /video/:id that provides the video consultation
 * experience. Handles the full flow from waiting room to in-call to
 * call ended states.
 *
 * Features:
 * - Protected route (requires authentication)
 * - Fetches video session based on appointment ID
 * - Shows waiting room with camera/mic preview
 * - Connects to LiveKit room after user joins
 * - Handles connection errors and disconnections
 * - Clean call ended state
 * - Responsive design
 *
 * Route: /video/:id
 *
 * @example
 * // URL: /video/appointment-123
 */
export default function VideoConsultationPage() {
  return (
    <ProtectedRoute>
      <VideoConsultationContent />
    </ProtectedRoute>
  );
}