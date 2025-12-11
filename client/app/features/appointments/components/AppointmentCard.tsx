import { useState, useCallback } from "react";
import { Card, CardContent, Button } from "~/components/ui";
import { cn } from "~/lib/utils";
import type { Appointment, AppointmentStatus } from "../types";

export interface AppointmentCardProps {
  /** Appointment data to display */
  appointment: Appointment;
  /** Callback when cancel button is clicked (receives appointment id) */
  onCancel?: (id: number) => void;
  /** Whether a cancel operation is in progress for this appointment */
  isCancelling?: boolean;
  /** Additional CSS classes for the card */
  className?: string;
}

/**
 * Get initials from a full name.
 * @param name - Full name string
 * @returns Two-letter initials (e.g., "John Doe" -> "JD")
 */
function getInitials(name: string): string {
  const parts = name.split(" ").filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

/**
 * Format a date string for display.
 * @param dateString - Date in YYYY-MM-DD format
 * @returns Formatted date (e.g., "Monday, December 15, 2025")
 */
function formatDateForDisplay(dateString: string): string {
  const date = new Date(dateString + "T00:00:00");
  return date.toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

/**
 * Format time from HH:mm to display format.
 * @param time - Time in HH:mm format
 * @returns Formatted time (e.g., "10:00 AM")
 */
function formatTimeForDisplay(time: string): string {
  const [hours, minutes] = time.split(":").map(Number);
  const period = hours >= 12 ? "PM" : "AM";
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes.toString().padStart(2, "0")} ${period}`;
}

/**
 * Check if an appointment date is in the future or today.
 * @param dateString - Date in YYYY-MM-DD format
 * @returns true if date is today or in the future
 */
function isUpcomingDate(dateString: string): boolean {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const appointmentDate = new Date(dateString + "T00:00:00");
  return appointmentDate >= today;
}

/**
 * Get status badge configuration.
 */
function getStatusBadgeConfig(status: AppointmentStatus): {
  label: string;
  className: string;
} {
  switch (status) {
    case "pending":
      return {
        label: "Pending",
        className: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400",
      };
    case "confirmed":
      return {
        label: "Confirmed",
        className: "bg-success-100 text-success-800 dark:bg-success-900/30 dark:text-success-400",
      };
    case "completed":
      return {
        label: "Completed",
        className: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400",
      };
    case "cancelled":
      return {
        label: "Cancelled",
        className: "bg-error-100 text-error-800 dark:bg-error-900/30 dark:text-error-400",
      };
    case "no_show":
      return {
        label: "No Show",
        className: "bg-error-100 text-error-700 dark:bg-error-900/30 dark:text-error-400",
      };
    default:
      return {
        label: status,
        className: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400",
      };
  }
}

/**
 * Get consultation type display name.
 */
function getConsultationTypeLabel(type: string): string {
  switch (type) {
    case "in_person":
      return "In Person";
    case "video":
      return "Video Call";
    case "phone":
      return "Phone Call";
    default:
      return type;
  }
}

/**
 * Confirmation Dialog Component
 */
interface ConfirmDialogProps {
  isOpen: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  isLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

function ConfirmDialog({
  isOpen,
  title,
  message,
  confirmLabel,
  isLoading,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="dialog-title"
    >
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onCancel}
        aria-hidden="true"
      />

      {/* Dialog */}
      <div className="relative bg-white dark:bg-gray-900 rounded-xl shadow-xl max-w-md w-full p-6 animate-in fade-in zoom-in-95 duration-200">
        <h3 id="dialog-title" className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          {title}
        </h3>
        <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">{message}</p>

        <div className="mt-6 flex gap-3 justify-end">
          <Button variant="ghost" onClick={onCancel} disabled={isLoading}>
            Keep Appointment
          </Button>
          <Button
            variant="primary"
            onClick={onConfirm}
            isLoading={isLoading}
            loadingText="Cancelling..."
            className="bg-error-600 hover:bg-error-700 active:bg-error-800 focus-visible:ring-error-500"
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}

/**
 * AppointmentCard component displays an appointment's information in a card layout.
 * Includes doctor avatar, name, specialty, appointment date/time, status badge,
 * and cancel button for eligible appointments.
 *
 * @example
 * <AppointmentCard
 *   appointment={appointmentData}
 *   onCancel={(id) => handleCancel(id)}
 *   isCancelling={false}
 * />
 */
export function AppointmentCard({
  appointment,
  onCancel,
  isCancelling = false,
  className,
}: AppointmentCardProps) {
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);

  // Determine doctor info
  const doctorName = appointment.doctor?.full_name ?? `Doctor #${appointment.doctor_id}`;
  const doctorSpecialty = appointment.doctor?.specialty ?? "Medical Professional";
  const initials = getInitials(doctorName);

  // Format date and time
  const formattedDate = formatDateForDisplay(appointment.appointment_date);
  const timeRange = `${formatTimeForDisplay(appointment.start_time)} - ${formatTimeForDisplay(appointment.end_time)}`;

  // Determine if cancel button should be shown
  const canCancel =
    (appointment.status === "pending" || appointment.status === "confirmed") &&
    isUpcomingDate(appointment.appointment_date);

  // Get status badge config
  const statusBadge = getStatusBadgeConfig(appointment.status);

  // Handle cancel button click
  const handleCancelClick = useCallback(() => {
    setShowConfirmDialog(true);
  }, []);

  // Handle dialog confirm
  const handleConfirmCancel = useCallback(() => {
    onCancel?.(appointment.id);
    setShowConfirmDialog(false);
  }, [appointment.id, onCancel]);

  // Handle dialog cancel
  const handleDialogClose = useCallback(() => {
    setShowConfirmDialog(false);
  }, []);

  return (
    <>
      <Card className={cn("flex flex-col h-full", className)} padding="none">
        <CardContent className="flex flex-col h-full p-4 sm:p-5">
          {/* Header: Avatar, Doctor Info, Status Badge */}
          <div className="flex items-start gap-4">
            {/* Avatar with Initials */}
            <div
              className={cn(
                "shrink-0 w-12 h-12 sm:w-14 sm:h-14",
                "flex items-center justify-center",
                "rounded-full bg-primary-100 dark:bg-primary-900",
                "text-primary-700 dark:text-primary-300",
                "text-base sm:text-lg font-semibold"
              )}
              aria-hidden="true"
            >
              {initials}
            </div>

            {/* Doctor Name and Specialty */}
            <div className="flex-1 min-w-0">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <h3 className="text-base sm:text-lg font-semibold text-gray-900 dark:text-gray-100 truncate">
                    {doctorName}
                  </h3>
                  <p className="mt-0.5 text-sm text-primary-600 dark:text-primary-400 font-medium">
                    {doctorSpecialty}
                  </p>
                </div>

                {/* Status Badge */}
                <span
                  className={cn(
                    "shrink-0 inline-flex items-center px-2.5 py-0.5 rounded-full",
                    "text-xs font-medium",
                    statusBadge.className
                  )}
                >
                  {statusBadge.label}
                </span>
              </div>
            </div>
          </div>

          {/* Appointment Details */}
          <div className="mt-4 space-y-2">
            {/* Date */}
            <div className="flex items-center gap-2 text-sm">
              <svg
                className="w-4 h-4 text-gray-400 shrink-0"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
              <span className="text-gray-700 dark:text-gray-300">{formattedDate}</span>
            </div>

            {/* Time */}
            <div className="flex items-center gap-2 text-sm">
              <svg
                className="w-4 h-4 text-gray-400 shrink-0"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <span className="text-gray-700 dark:text-gray-300">{timeRange}</span>
            </div>

            {/* Consultation Type */}
            <div className="flex items-center gap-2 text-sm">
              <svg
                className="w-4 h-4 text-gray-400 shrink-0"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                {appointment.consultation_type === "video" ? (
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                  />
                ) : appointment.consultation_type === "phone" ? (
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
                  />
                ) : (
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                  />
                )}
              </svg>
              <span className="text-gray-700 dark:text-gray-300">
                {getConsultationTypeLabel(appointment.consultation_type)}
              </span>
            </div>

            {/* Reason (if present) */}
            {appointment.reason && (
              <div className="flex items-start gap-2 text-sm">
                <svg
                  className="w-4 h-4 text-gray-400 shrink-0 mt-0.5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
                <span className="text-gray-600 dark:text-gray-400 line-clamp-2">
                  {appointment.reason}
                </span>
              </div>
            )}
          </div>

          {/* Cancel Button - only for eligible appointments */}
          {canCancel && onCancel && (
            <div className="mt-auto pt-4">
              <Button
                variant="outline"
                fullWidth
                onClick={handleCancelClick}
                disabled={isCancelling}
                isLoading={isCancelling}
                loadingText="Cancelling..."
                className="border-error-300 text-error-600 hover:bg-error-50 active:bg-error-100 focus-visible:ring-error-500 dark:border-error-700 dark:text-error-400 dark:hover:bg-error-900/30"
                aria-label={`Cancel appointment with ${doctorName} on ${formattedDate}`}
              >
                Cancel Appointment
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Confirmation Dialog */}
      <ConfirmDialog
        isOpen={showConfirmDialog}
        title="Cancel Appointment"
        message={`Are you sure you want to cancel your appointment with ${doctorName} on ${formattedDate}? This action cannot be undone.`}
        confirmLabel="Yes, Cancel"
        isLoading={isCancelling}
        onConfirm={handleConfirmCancel}
        onCancel={handleDialogClose}
      />
    </>
  );
}
