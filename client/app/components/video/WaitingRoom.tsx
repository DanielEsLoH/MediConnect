import { useState, useCallback, useEffect } from "react";
import { PreJoin } from "@livekit/components-react";
import type { LocalUserChoices } from "@livekit/components-react";
import { cn } from "~/lib/utils";
import { Button } from "~/components/ui";
import type { AppointmentInfo } from "~/features/video/types";

/**
 * Props for the WaitingRoom component.
 */
export interface WaitingRoomProps {
  /** Appointment information to display */
  appointmentInfo: AppointmentInfo;
  /** Callback when user is ready to join */
  onJoin: (userChoices: LocalUserChoices) => void;
  /** Whether currently joining */
  isJoining?: boolean;
  /** Error message to display */
  error?: string;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Calendar icon for appointment date.
 */
function CalendarIcon({ className }: { className?: string }) {
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
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  );
}

/**
 * Clock icon for appointment time.
 */
function ClockIcon({ className }: { className?: string }) {
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
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </svg>
  );
}

/**
 * User icon for doctor.
 */
function UserIcon({ className }: { className?: string }) {
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
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}

/**
 * Video icon for consultation.
 */
function VideoIcon({ className }: { className?: string }) {
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
 * Format scheduled time for display.
 */
function formatScheduledTime(isoString: string): { date: string; time: string } {
  const date = new Date(isoString);

  return {
    date: date.toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    }),
    time: date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }),
  };
}

/**
 * WaitingRoom Component
 *
 * Pre-join waiting room for video consultations with camera/mic preview
 * and device selection.
 *
 * Features:
 * - Camera and microphone preview using LiveKit's PreJoin component
 * - Device selection (camera, microphone, audio output)
 * - Appointment information display
 * - Join button to enter the video room
 * - Loading and error states
 * - Responsive design
 * - Accessibility support
 *
 * @example
 * <WaitingRoom
 *   appointmentInfo={{
 *     doctorName: "Dr. Sarah Chen",
 *     doctorSpecialty: "General Medicine",
 *     scheduledTime: "2024-03-15T14:00:00Z",
 *     durationMinutes: 30
 *   }}
 *   onJoin={handleJoin}
 * />
 */
export function WaitingRoom({
  appointmentInfo,
  onJoin,
  isJoining = false,
  error,
  className,
}: WaitingRoomProps) {
  const [permissionError, setPermissionError] = useState<string | null>(null);
  const [userChoices, setUserChoices] = useState<LocalUserChoices | null>(null);

  const { date, time } = formatScheduledTime(appointmentInfo.scheduledTime);

  /**
   * Handle PreJoin submit.
   */
  const handlePreJoinSubmit = useCallback(
    (choices: LocalUserChoices) => {
      setUserChoices(choices);
      onJoin(choices);
    },
    [onJoin]
  );

  /**
   * Handle PreJoin error (e.g., permission denied).
   */
  const handlePreJoinError = useCallback((err: Error) => {
    console.error("PreJoin error:", err);

    if (err.name === "NotAllowedError" || err.message.includes("Permission")) {
      setPermissionError(
        "Camera or microphone access was denied. Please allow access in your browser settings and refresh the page."
      );
    } else if (err.name === "NotFoundError") {
      setPermissionError(
        "No camera or microphone found. Please connect a device and refresh the page."
      );
    } else {
      setPermissionError(
        "Failed to access camera or microphone. Please check your device settings."
      );
    }
  }, []);

  return (
    <div
      className={cn(
        "min-h-screen bg-gray-50 dark:bg-gray-950",
        "py-8 px-4",
        className
      )}
    >
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <div
            className={cn(
              "inline-flex items-center justify-center",
              "w-16 h-16 rounded-full",
              "bg-primary-100 dark:bg-primary-900/30",
              "mb-4"
            )}
          >
            <VideoIcon className="w-8 h-8 text-primary-600 dark:text-primary-400" />
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Video Consultation
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Set up your camera and microphone before joining
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-8">
          {/* Left: Appointment Info */}
          <div className="order-2 lg:order-1">
            <div
              className={cn(
                "bg-white dark:bg-gray-900",
                "rounded-xl shadow-sm",
                "border border-gray-200 dark:border-gray-800",
                "p-6"
              )}
            >
              <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
                Appointment Details
              </h2>

              <div className="space-y-4">
                {/* Doctor */}
                <div className="flex items-start gap-3">
                  <div
                    className={cn(
                      "flex-shrink-0 w-10 h-10 rounded-full",
                      "bg-primary-100 dark:bg-primary-900/30",
                      "flex items-center justify-center"
                    )}
                  >
                    <UserIcon className="w-5 h-5 text-primary-600 dark:text-primary-400" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-gray-100">
                      {appointmentInfo.doctorName}
                    </p>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      {appointmentInfo.doctorSpecialty}
                    </p>
                  </div>
                </div>

                {/* Date */}
                <div className="flex items-start gap-3">
                  <div
                    className={cn(
                      "flex-shrink-0 w-10 h-10 rounded-full",
                      "bg-gray-100 dark:bg-gray-800",
                      "flex items-center justify-center"
                    )}
                  >
                    <CalendarIcon className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-gray-100">
                      {date}
                    </p>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      Scheduled date
                    </p>
                  </div>
                </div>

                {/* Time */}
                <div className="flex items-start gap-3">
                  <div
                    className={cn(
                      "flex-shrink-0 w-10 h-10 rounded-full",
                      "bg-gray-100 dark:bg-gray-800",
                      "flex items-center justify-center"
                    )}
                  >
                    <ClockIcon className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-gray-100">
                      {time}
                    </p>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      Duration: {appointmentInfo.durationMinutes} minutes
                    </p>
                  </div>
                </div>
              </div>

              {/* Tips */}
              <div
                className={cn(
                  "mt-6 p-4 rounded-lg",
                  "bg-blue-50 dark:bg-blue-900/20",
                  "border border-blue-200 dark:border-blue-800"
                )}
              >
                <h3 className="text-sm font-medium text-blue-800 dark:text-blue-200 mb-2">
                  Before you join:
                </h3>
                <ul className="text-sm text-blue-700 dark:text-blue-300 space-y-1">
                  <li>- Ensure you have a stable internet connection</li>
                  <li>- Find a quiet, well-lit space</li>
                  <li>- Test your camera and microphone</li>
                  <li>- Have any relevant documents ready</li>
                </ul>
              </div>
            </div>
          </div>

          {/* Right: Camera Preview */}
          <div className="order-1 lg:order-2">
            <div
              className={cn(
                "bg-white dark:bg-gray-900",
                "rounded-xl shadow-sm",
                "border border-gray-200 dark:border-gray-800",
                "overflow-hidden"
              )}
            >
              {/* Error Messages */}
              {(error || permissionError) && (
                <div
                  className={cn(
                    "p-4",
                    "bg-red-50 dark:bg-red-900/20",
                    "border-b border-red-200 dark:border-red-800"
                  )}
                  role="alert"
                >
                  <p className="text-sm text-red-700 dark:text-red-300">
                    {error || permissionError}
                  </p>
                </div>
              )}

              {/* PreJoin Component */}
              <div className="p-4">
                <PreJoin
                  onSubmit={handlePreJoinSubmit}
                  onError={handlePreJoinError}
                  defaults={{
                    username: "",
                    videoEnabled: true,
                    audioEnabled: true,
                  }}
                  joinLabel={isJoining ? "Joining..." : "Join Consultation"}
                  micLabel="Microphone"
                  camLabel="Camera"
                  userLabel="Your Name"
                  data-lk-theme="default"
                />
              </div>

              {/* Custom Join Button (backup if PreJoin doesn't show one) */}
              {userChoices && !isJoining && (
                <div className="p-4 pt-0">
                  <Button
                    variant="primary"
                    size="lg"
                    fullWidth
                    onClick={() => onJoin(userChoices)}
                    isLoading={isJoining}
                  >
                    Join Consultation
                  </Button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}