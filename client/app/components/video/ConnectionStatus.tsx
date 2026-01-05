import { cn } from "~/lib/utils";
import { VideoSessionStatus } from "~/features/video/types";

/**
 * Props for the ConnectionStatus component.
 */
export interface ConnectionStatusProps {
  /** Current connection status */
  status: VideoSessionStatus;
  /** Error message to display when status is ERROR */
  errorMessage?: string;
  /** Whether to show as a compact indicator */
  compact?: boolean;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Status configuration for display.
 */
interface StatusConfig {
  label: string;
  color: string;
  bgColor: string;
  icon: React.ReactNode;
  showSpinner?: boolean;
}

/**
 * Spinner icon component for loading states.
 */
function SpinnerIcon({ className }: { className?: string }) {
  return (
    <svg
      className={cn("animate-spin", className)}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
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
  );
}

/**
 * Check icon for connected state.
 */
function CheckIcon({ className }: { className?: string }) {
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
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

/**
 * Warning icon for error state.
 */
function WarningIcon({ className }: { className?: string }) {
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
      <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>
  );
}

/**
 * Disconnect icon for disconnected state.
 */
function DisconnectIcon({ className }: { className?: string }) {
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
      <path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55" />
      <path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39" />
      <path d="M10.71 5.05A16 16 0 0 1 22.58 9" />
      <path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88" />
      <path d="M8.53 16.11a6 6 0 0 1 6.95 0" />
      <line x1="12" y1="20" x2="12.01" y2="20" />
    </svg>
  );
}

/**
 * Clock icon for waiting state.
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
 * Get status configuration based on current status.
 */
function getStatusConfig(status: VideoSessionStatus): StatusConfig {
  switch (status) {
    case VideoSessionStatus.WAITING:
      return {
        label: "Waiting",
        color: "text-yellow-600 dark:text-yellow-400",
        bgColor: "bg-yellow-100 dark:bg-yellow-900/30",
        icon: <ClockIcon className="w-4 h-4" />,
      };
    case VideoSessionStatus.CONNECTING:
      return {
        label: "Connecting",
        color: "text-blue-600 dark:text-blue-400",
        bgColor: "bg-blue-100 dark:bg-blue-900/30",
        icon: <SpinnerIcon className="w-4 h-4" />,
        showSpinner: true,
      };
    case VideoSessionStatus.CONNECTED:
      return {
        label: "Connected",
        color: "text-green-600 dark:text-green-400",
        bgColor: "bg-green-100 dark:bg-green-900/30",
        icon: <CheckIcon className="w-4 h-4" />,
      };
    case VideoSessionStatus.DISCONNECTED:
      return {
        label: "Disconnected",
        color: "text-gray-600 dark:text-gray-400",
        bgColor: "bg-gray-100 dark:bg-gray-800",
        icon: <DisconnectIcon className="w-4 h-4" />,
      };
    case VideoSessionStatus.ERROR:
      return {
        label: "Error",
        color: "text-red-600 dark:text-red-400",
        bgColor: "bg-red-100 dark:bg-red-900/30",
        icon: <WarningIcon className="w-4 h-4" />,
      };
    default:
      return {
        label: "Unknown",
        color: "text-gray-600 dark:text-gray-400",
        bgColor: "bg-gray-100 dark:bg-gray-800",
        icon: <ClockIcon className="w-4 h-4" />,
      };
  }
}

/**
 * ConnectionStatus Component
 *
 * Displays the current connection state for the video consultation.
 * Shows different icons and colors based on connection status.
 *
 * Features:
 * - Visual status indicators with icons
 * - Color-coded states
 * - Compact mode for toolbar display
 * - Error message display
 * - Accessible with screen reader support
 *
 * @example
 * <ConnectionStatus status={VideoSessionStatus.CONNECTED} />
 * <ConnectionStatus status={VideoSessionStatus.ERROR} errorMessage="Connection lost" />
 * <ConnectionStatus status={VideoSessionStatus.CONNECTING} compact />
 */
export function ConnectionStatus({
  status,
  errorMessage,
  compact = false,
  className,
}: ConnectionStatusProps) {
  const config = getStatusConfig(status);

  if (compact) {
    return (
      <div
        className={cn(
          "inline-flex items-center gap-1.5",
          config.color,
          className
        )}
        role="status"
        aria-live="polite"
      >
        <span
          className={cn(
            "w-2 h-2 rounded-full",
            status === VideoSessionStatus.CONNECTED && "bg-green-500",
            status === VideoSessionStatus.CONNECTING && "bg-blue-500 animate-pulse",
            status === VideoSessionStatus.WAITING && "bg-yellow-500",
            status === VideoSessionStatus.DISCONNECTED && "bg-gray-500",
            status === VideoSessionStatus.ERROR && "bg-red-500"
          )}
          aria-hidden="true"
        />
        <span className="sr-only">{config.label}</span>
      </div>
    );
  }

  return (
    <div
      className={cn(
        "inline-flex flex-col items-start gap-1",
        className
      )}
      role="status"
      aria-live="polite"
    >
      <div
        className={cn(
          "inline-flex items-center gap-2 px-3 py-1.5 rounded-full",
          config.bgColor,
          config.color
        )}
      >
        {config.icon}
        <span className="text-sm font-medium">{config.label}</span>
      </div>

      {status === VideoSessionStatus.ERROR && errorMessage && (
        <p className="text-sm text-red-600 dark:text-red-400 ml-1">
          {errorMessage}
        </p>
      )}

      {status === VideoSessionStatus.CONNECTING && (
        <p className="text-xs text-gray-500 dark:text-gray-400 ml-1">
          Please wait while we establish a connection...
        </p>
      )}
    </div>
  );
}