import { useCallback } from "react";
import { Link } from "react-router";
import { useBookingStore } from "../../store/bookingStore";
import { Button } from "~/components/ui";
import { cn } from "~/lib/utils";

export interface ConfirmationStepProps {
  /** Doctor's full name */
  doctorName: string;
  /** Doctor's specialty */
  doctorSpecialty: string;
  /** Consultation fee */
  consultationFee: number;
}

/**
 * Format date for display.
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
 * Format consultation type for display.
 */
function formatConsultationType(type: string): string {
  switch (type) {
    case "in_person":
      return "In-Person Visit";
    case "video":
      return "Video Consultation";
    case "phone":
      return "Phone Consultation";
    default:
      return type;
  }
}

/**
 * Format currency value.
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

/**
 * Confirmation Step (Step 6)
 *
 * Displays:
 * - Success message
 * - Complete appointment summary
 * - Appointment ID and reference number
 * - Actions (View Appointment, Add to Calendar, Print)
 * - Next steps and instructions
 */
export function ConfirmationStep({
  doctorName,
  doctorSpecialty,
  consultationFee,
}: ConfirmationStepProps) {
  const {
    appointmentId,
    selectedDate,
    startTime,
    endTime,
    consultationType,
    reason,
    personalData,
  } = useBookingStore();

  // Handle print
  const handlePrint = useCallback(() => {
    window.print();
  }, []);

  // Handle add to calendar (basic implementation)
  const handleAddToCalendar = useCallback(() => {
    if (!selectedDate || !startTime || !endTime) return;

    // Create ICS file content
    const startDateTime = `${selectedDate.replace(/-/g, "")}T${startTime.replace(/:/, "")}00`;
    const endDateTime = `${selectedDate.replace(/-/g, "")}T${endTime.replace(/:/, "")}00`;

    const icsContent = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "BEGIN:VEVENT",
      `DTSTART:${startDateTime}`,
      `DTEND:${endDateTime}`,
      `SUMMARY:Appointment with ${doctorName}`,
      `DESCRIPTION:${consultationType} consultation with ${doctorName} (${doctorSpecialty})`,
      `LOCATION:${consultationType === "in_person" ? "Doctor's Clinic" : "Remote"}`,
      "END:VEVENT",
      "END:VCALENDAR",
    ].join("\r\n");

    // Create download link
    const blob = new Blob([icsContent], { type: "text/calendar" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `appointment-${appointmentId}.ics`;
    link.click();
    URL.revokeObjectURL(url);
  }, [selectedDate, startTime, endTime, doctorName, doctorSpecialty, consultationType, appointmentId]);

  return (
    <div className="space-y-6">
      {/* Success Header */}
      <div className="text-center py-8">
        <div className="w-20 h-20 rounded-full bg-success-100 dark:bg-success-900 flex items-center justify-center mx-auto mb-4 animate-in zoom-in duration-500">
          <svg
            className="w-10 h-10 text-success-600 dark:text-success-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M5 13l4 4L19 7"
            />
          </svg>
        </div>
        <h2 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Appointment Confirmed!
        </h2>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Your appointment has been successfully booked
        </p>
        {appointmentId && (
          <div className="mt-4 inline-flex items-center gap-2 px-4 py-2 bg-gray-100 dark:bg-gray-800 rounded-lg">
            <span className="text-sm text-gray-500 dark:text-gray-400">
              Reference:
            </span>
            <span className="text-sm font-mono font-bold text-gray-900 dark:text-gray-100">
              #{appointmentId.toString().padStart(6, "0")}
            </span>
          </div>
        )}
      </div>

      {/* Appointment Summary Card */}
      <div className="bg-gradient-to-br from-primary-50 to-primary-100 dark:from-primary-950 dark:to-primary-900 rounded-xl p-6 border border-primary-200 dark:border-primary-800">
        <h3 className="text-lg font-semibold text-primary-900 dark:text-primary-100 mb-4">
          Appointment Details
        </h3>

        <div className="space-y-3">
          {/* Doctor */}
          <div className="flex items-start gap-3">
            <svg
              className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
            <div className="flex-1">
              <p className="text-sm text-primary-700 dark:text-primary-300">Doctor</p>
              <p className="font-semibold text-primary-900 dark:text-primary-100">
                {doctorName}
              </p>
              <p className="text-sm text-primary-600 dark:text-primary-400">
                {doctorSpecialty}
              </p>
            </div>
          </div>

          {/* Date & Time */}
          <div className="flex items-start gap-3">
            <svg
              className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
            <div className="flex-1">
              <p className="text-sm text-primary-700 dark:text-primary-300">
                Date & Time
              </p>
              <p className="font-semibold text-primary-900 dark:text-primary-100">
                {selectedDate && formatDateForDisplay(selectedDate)}
              </p>
              <p className="text-sm text-primary-600 dark:text-primary-400">
                {startTime} - {endTime}
              </p>
            </div>
          </div>

          {/* Consultation Type */}
          <div className="flex items-start gap-3">
            <svg
              className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
              />
            </svg>
            <div className="flex-1">
              <p className="text-sm text-primary-700 dark:text-primary-300">
                Consultation Type
              </p>
              <p className="font-semibold text-primary-900 dark:text-primary-100">
                {consultationType && formatConsultationType(consultationType)}
              </p>
            </div>
          </div>

          {/* Contact Info */}
          {personalData && (
            <div className="flex items-start gap-3">
              <svg
                className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0 mt-0.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                />
              </svg>
              <div className="flex-1">
                <p className="text-sm text-primary-700 dark:text-primary-300">
                  Contact Information
                </p>
                <p className="text-sm text-primary-900 dark:text-primary-100">
                  {personalData.email}
                </p>
                <p className="text-sm text-primary-900 dark:text-primary-100">
                  {personalData.phone}
                </p>
              </div>
            </div>
          )}

          {/* Reason (if provided) */}
          {reason && (
            <div className="flex items-start gap-3">
              <svg
                className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0 mt-0.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
              <div className="flex-1">
                <p className="text-sm text-primary-700 dark:text-primary-300">Reason</p>
                <p className="text-sm text-primary-900 dark:text-primary-100">
                  {reason}
                </p>
              </div>
            </div>
          )}

          {/* Fee */}
          <div className="pt-3 border-t border-primary-200 dark:border-primary-800">
            <div className="flex items-center justify-between">
              <span className="text-sm text-primary-700 dark:text-primary-300">
                Consultation Fee
              </span>
              <span className="text-lg font-bold text-primary-900 dark:text-primary-100">
                {formatCurrency(consultationFee)}
              </span>
            </div>
            <p className="text-xs text-primary-600 dark:text-primary-400 mt-1">
              Paid via Stripe
            </p>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <Link to={`/appointments/${appointmentId}`} className="block">
          <Button variant="primary" fullWidth>
            View Appointment
          </Button>
        </Link>
        <Button variant="outline" fullWidth onClick={handleAddToCalendar}>
          Add to Calendar
        </Button>
        <Button variant="outline" fullWidth onClick={handlePrint}>
          Print
        </Button>
      </div>

      {/* Next Steps */}
      <div className="bg-blue-50 dark:bg-blue-950 rounded-lg p-4 border border-blue-200 dark:border-blue-800">
        <h4 className="text-sm font-semibold text-blue-900 dark:text-blue-100 mb-2">
          What's Next?
        </h4>
        <ul className="space-y-2 text-sm text-blue-700 dark:text-blue-300">
          <li className="flex items-start gap-2">
            <svg
              className="w-4 h-4 shrink-0 mt-0.5"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fillRule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clipRule="evenodd"
              />
            </svg>
            <span>
              You'll receive a confirmation email at{" "}
              <strong>{personalData?.email}</strong>
            </span>
          </li>
          <li className="flex items-start gap-2">
            <svg
              className="w-4 h-4 shrink-0 mt-0.5"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fillRule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clipRule="evenodd"
              />
            </svg>
            <span>We'll send you a reminder 24 hours before your appointment</span>
          </li>
          <li className="flex items-start gap-2">
            <svg
              className="w-4 h-4 shrink-0 mt-0.5"
              fill="currentColor"
              viewBox="0 0 20 20"
            >
              <path
                fillRule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clipRule="evenodd"
              />
            </svg>
            <span>
              {consultationType === "video"
                ? "You'll receive a video call link before your appointment"
                : consultationType === "phone"
                  ? "The doctor will call you at the scheduled time"
                  : "Please arrive 10 minutes early to the clinic"}
            </span>
          </li>
        </ul>
      </div>

      {/* Return Home */}
      <div className="text-center pt-4">
        <Link to="/">
          <Button variant="ghost">Return to Home</Button>
        </Link>
      </div>
    </div>
  );
}
