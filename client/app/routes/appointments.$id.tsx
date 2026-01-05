import { useState, useCallback } from "react";
import { Link, useParams, useNavigate } from "react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { Button, Card, CardHeader, CardTitle, CardContent, CardFooter, Spinner } from "~/components/ui";
import { ReviewForm, StarRating, ReviewItem } from "~/components/reviews";
import { cn } from "~/lib/utils";
import {
  appointmentsApi,
  type Appointment,
  type AppointmentStatus,
} from "~/features/appointments";
import { doctorsApi, type Doctor } from "~/features/doctors";
import { reviewsApi, type Review, type CreateReviewPayload } from "~/features/reviews";

/**
 * Query keys for appointment detail page.
 */
const appointmentKeys = {
  detail: (id: number) => ["appointments", "detail", id] as const,
  canReview: (id: number) => ["appointments", "canReview", id] as const,
  myReview: (id: number) => ["appointments", "myReview", id] as const,
};

const doctorKeys = {
  detail: (id: number) => ["doctors", "detail", id] as const,
};

/**
 * Format a date string for display.
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
 */
function formatTimeForDisplay(time: string): string {
  const [hours, minutes] = time.split(":").map(Number);
  const period = hours >= 12 ? "PM" : "AM";
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes.toString().padStart(2, "0")} ${period}`;
}

/**
 * Calculate appointment duration in minutes.
 */
function calculateDuration(startTime: string, endTime: string): number {
  const [startHours, startMins] = startTime.split(":").map(Number);
  const [endHours, endMins] = endTime.split(":").map(Number);
  const startTotalMins = startHours * 60 + startMins;
  const endTotalMins = endHours * 60 + endMins;
  return endTotalMins - startTotalMins;
}

/**
 * Get initials from a full name.
 */
function getInitials(name: string): string {
  const parts = name.split(" ").filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

/**
 * Get status badge configuration.
 */
function getStatusBadgeConfig(status: AppointmentStatus): {
  label: string;
  className: string;
  bgClassName: string;
} {
  switch (status) {
    case "pending":
      return {
        label: "Pending Confirmation",
        className: "text-amber-800 dark:text-amber-400",
        bgClassName: "bg-amber-100 dark:bg-amber-900/30",
      };
    case "confirmed":
      return {
        label: "Confirmed",
        className: "text-success-800 dark:text-success-400",
        bgClassName: "bg-success-100 dark:bg-success-900/30",
      };
    case "completed":
      return {
        label: "Completed",
        className: "text-gray-700 dark:text-gray-300",
        bgClassName: "bg-gray-100 dark:bg-gray-800",
      };
    case "cancelled":
      return {
        label: "Cancelled",
        className: "text-error-800 dark:text-error-400",
        bgClassName: "bg-error-100 dark:bg-error-900/30",
      };
    case "no_show":
      return {
        label: "No Show",
        className: "text-error-700 dark:text-error-400",
        bgClassName: "bg-error-100 dark:bg-error-900/30",
      };
    default:
      return {
        label: status,
        className: "text-gray-600 dark:text-gray-400",
        bgClassName: "bg-gray-100 dark:bg-gray-800",
      };
  }
}

/**
 * Get consultation type display info.
 */
function getConsultationTypeInfo(type: string): {
  label: string;
  icon: React.ReactNode;
  description: string;
} {
  switch (type) {
    case "video":
      return {
        label: "Video Consultation",
        description: "Join via secure video call",
        icon: (
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
            />
          </svg>
        ),
      };
    case "phone":
      return {
        label: "Phone Consultation",
        description: "Doctor will call you",
        icon: (
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
            />
          </svg>
        ),
      };
    case "in_person":
    default:
      return {
        label: "In-Person Visit",
        description: "Visit the clinic location",
        icon: (
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
            />
          </svg>
        ),
      };
  }
}

/**
 * Confirmation Dialog Component.
 */
interface ConfirmDialogProps {
  isOpen: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  variant?: "danger" | "primary";
  isLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

function ConfirmDialog({
  isOpen,
  title,
  message,
  confirmLabel,
  variant = "danger",
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
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={onConfirm}
            isLoading={isLoading}
            loadingText="Processing..."
            className={
              variant === "danger"
                ? "bg-error-600 hover:bg-error-700 active:bg-error-800 focus-visible:ring-error-500"
                : ""
            }
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}

/**
 * Error State Component.
 */
interface ErrorStateProps {
  message: string;
  onRetry?: () => void;
  onBack?: () => void;
}

function ErrorState({ message, onRetry, onBack }: ErrorStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="w-16 h-16 rounded-full bg-error-100 dark:bg-error-900/30 flex items-center justify-center mb-4">
        <svg
          className="w-8 h-8 text-error-600 dark:text-error-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
          />
        </svg>
      </div>
      <h2 className="text-lg font-medium text-gray-900 dark:text-gray-100">
        Something went wrong
      </h2>
      <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">{message}</p>
      <div className="mt-6 flex gap-3">
        {onBack && (
          <Button variant="outline" onClick={onBack}>
            Go Back
          </Button>
        )}
        {onRetry && (
          <Button variant="primary" onClick={onRetry}>
            Try Again
          </Button>
        )}
      </div>
    </div>
  );
}

/**
 * Appointment Detail Page Component
 *
 * Full appointment detail view with:
 * - Doctor info card
 * - Appointment date/time/status
 * - Actions (cancel, reschedule, join video)
 * - Pre-appointment instructions
 * - Notes section
 * - Review section
 */
export default function AppointmentDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const appointmentId = id ? parseInt(id, 10) : 0;

  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [showReviewForm, setShowReviewForm] = useState(false);
  const [patientNotes, setPatientNotes] = useState("");

  // Fetch appointment details
  const {
    data: appointment,
    isLoading: isLoadingAppointment,
    isError: isAppointmentError,
    error: appointmentError,
    refetch: refetchAppointment,
  } = useQuery({
    queryKey: appointmentKeys.detail(appointmentId),
    queryFn: () => appointmentsApi.getAppointmentById(appointmentId),
    enabled: appointmentId > 0,
    staleTime: 1000 * 60 * 2,
  });

  // Fetch doctor details
  const { data: doctor } = useQuery({
    queryKey: doctorKeys.detail(appointment?.doctor_id ?? 0),
    queryFn: () => doctorsApi.getDoctorById(appointment!.doctor_id),
    enabled: !!appointment?.doctor_id,
    staleTime: 1000 * 60 * 5,
  });

  // Check if user can review this appointment
  const { data: canReviewData } = useQuery({
    queryKey: appointmentKeys.canReview(appointmentId),
    queryFn: () => reviewsApi.canReviewAppointment(appointmentId.toString()),
    enabled: appointment?.status === "completed",
    staleTime: 1000 * 60,
  });

  // Get existing review for this appointment
  const { data: existingReview, refetch: refetchReview } = useQuery({
    queryKey: appointmentKeys.myReview(appointmentId),
    queryFn: () => reviewsApi.getMyReviewForAppointment(appointmentId.toString()),
    enabled: appointment?.status === "completed",
    staleTime: 1000 * 60,
  });

  // Cancel appointment mutation
  const cancelMutation = useMutation({
    mutationFn: () => appointmentsApi.cancelAppointment(appointmentId),
    onSuccess: () => {
      toast.success("Appointment cancelled successfully");
      setShowCancelDialog(false);
      queryClient.invalidateQueries({ queryKey: appointmentKeys.detail(appointmentId) });
      queryClient.invalidateQueries({ queryKey: ["appointments"] });
    },
    onError: (error) => {
      const message =
        error instanceof Error ? error.message : "Failed to cancel appointment";
      toast.error(message);
    },
  });

  // Create review mutation
  const createReviewMutation = useMutation({
    mutationFn: (payload: CreateReviewPayload) => reviewsApi.createReview(payload),
    onSuccess: () => {
      toast.success("Review submitted successfully!");
      setShowReviewForm(false);
      refetchReview();
      queryClient.invalidateQueries({ queryKey: appointmentKeys.canReview(appointmentId) });
    },
    onError: (error) => {
      const message = error instanceof Error ? error.message : "Failed to submit review";
      toast.error(message);
    },
  });

  // Handle cancel click
  const handleCancelClick = useCallback(() => {
    setShowCancelDialog(true);
  }, []);

  // Handle cancel confirm
  const handleConfirmCancel = useCallback(() => {
    cancelMutation.mutate();
  }, [cancelMutation]);

  // Handle dialog close
  const handleDialogClose = useCallback(() => {
    setShowCancelDialog(false);
  }, []);

  // Handle review submit
  const handleReviewSubmit = useCallback(
    async (data: CreateReviewPayload | { rating?: number; title?: string | null; comment?: string | null }) => {
      // Since we're creating a new review, we know this is CreateReviewPayload
      await createReviewMutation.mutateAsync(data as CreateReviewPayload);
    },
    [createReviewMutation]
  );

  // Handle back navigation
  const handleBack = useCallback(() => {
    navigate("/appointments");
  }, [navigate]);

  // Loading state
  if (isLoadingAppointment) {
    return (
      <div className="max-w-4xl mx-auto py-8">
        <div className="flex items-center justify-center py-16">
          <Spinner size="lg" label="Loading appointment details..." />
        </div>
      </div>
    );
  }

  // Error state
  if (isAppointmentError || !appointment) {
    return (
      <div className="max-w-4xl mx-auto py-8">
        <ErrorState
          message={
            appointmentError instanceof Error
              ? appointmentError.message
              : "Appointment not found or unable to load details."
          }
          onRetry={() => refetchAppointment()}
          onBack={handleBack}
        />
      </div>
    );
  }

  const doctorName = doctor?.full_name ?? appointment.doctor?.full_name ?? `Doctor #${appointment.doctor_id}`;
  const doctorSpecialty = doctor?.specialty ?? appointment.doctor?.specialty ?? "Medical Professional";
  const statusBadge = getStatusBadgeConfig(appointment.status);
  const consultationType = getConsultationTypeInfo(appointment.consultation_type);
  const duration = calculateDuration(appointment.start_time, appointment.end_time);
  const initials = getInitials(doctorName);

  // Determine available actions
  const canCancel =
    (appointment.status === "pending" || appointment.status === "confirmed") &&
    new Date(appointment.appointment_date + "T00:00:00") >= new Date(new Date().toDateString());
  const canJoinVideo =
    appointment.consultation_type === "video" &&
    (appointment.status === "confirmed" || appointment.status === "pending");
  const canReview =
    appointment.status === "completed" &&
    canReviewData?.can_review === true &&
    !existingReview;

  return (
    <>
      <div className="max-w-4xl mx-auto">
        {/* Back Button */}
        <div className="mb-6">
          <Link
            to="/appointments"
            className="inline-flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100 transition-colors"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to Appointments
          </Link>
        </div>

        {/* Main Content Grid */}
        <div className="grid gap-6 lg:grid-cols-3">
          {/* Left Column - Appointment Info */}
          <div className="lg:col-span-2 space-y-6">
            {/* Appointment Info Card */}
            <Card>
              <CardContent>
                {/* Status Badge */}
                <div className="flex items-center justify-between mb-6">
                  <span
                    className={cn(
                      "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium",
                      statusBadge.bgClassName,
                      statusBadge.className
                    )}
                  >
                    {statusBadge.label}
                  </span>
                  <span className="text-sm text-gray-500 dark:text-gray-400">
                    #{appointment.id}
                  </span>
                </div>

                {/* Doctor Info */}
                <div className="flex items-start gap-4 mb-6 pb-6 border-b border-gray-200 dark:border-gray-700">
                  {/* Avatar */}
                  <div
                    className={cn(
                      "shrink-0 w-16 h-16 rounded-full flex items-center justify-center",
                      "bg-primary-100 dark:bg-primary-900",
                      "text-primary-700 dark:text-primary-300",
                      "text-xl font-semibold"
                    )}
                  >
                    {initials}
                  </div>

                  {/* Doctor Details */}
                  <div className="flex-1">
                    <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">
                      {doctorName}
                    </h2>
                    <p className="text-primary-600 dark:text-primary-400 font-medium">
                      {doctorSpecialty}
                    </p>
                    {doctor?.rating && (
                      <div className="flex items-center gap-2 mt-2">
                        <StarRating rating={doctor.rating} size="sm" />
                        <span className="text-sm text-gray-500 dark:text-gray-400">
                          ({doctor.total_reviews} reviews)
                        </span>
                      </div>
                    )}
                  </div>

                  {/* View Doctor Profile */}
                  <Link
                    to={`/doctors/${appointment.doctor_id}`}
                    className="text-sm font-medium text-primary-600 hover:text-primary-700 dark:text-primary-400"
                  >
                    View Profile
                  </Link>
                </div>

                {/* Appointment Details */}
                <div className="grid gap-4 sm:grid-cols-2">
                  {/* Date */}
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400">
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                        />
                      </svg>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Date</p>
                      <p className="font-medium text-gray-900 dark:text-gray-100">
                        {formatDateForDisplay(appointment.appointment_date)}
                      </p>
                    </div>
                  </div>

                  {/* Time */}
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400">
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Time</p>
                      <p className="font-medium text-gray-900 dark:text-gray-100">
                        {formatTimeForDisplay(appointment.start_time)} - {formatTimeForDisplay(appointment.end_time)}
                      </p>
                    </div>
                  </div>

                  {/* Duration */}
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400">
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M13 10V3L4 14h7v7l9-11h-7z"
                        />
                      </svg>
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Duration</p>
                      <p className="font-medium text-gray-900 dark:text-gray-100">
                        {duration} minutes
                      </p>
                    </div>
                  </div>

                  {/* Consultation Type */}
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400">
                      {consultationType.icon}
                    </div>
                    <div>
                      <p className="text-sm text-gray-500 dark:text-gray-400">Type</p>
                      <p className="font-medium text-gray-900 dark:text-gray-100">
                        {consultationType.label}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Reason */}
                {appointment.reason && (
                  <div className="mt-6 pt-6 border-t border-gray-200 dark:border-gray-700">
                    <h3 className="text-sm font-medium text-gray-500 dark:text-gray-400 mb-2">
                      Reason for Visit
                    </h3>
                    <p className="text-gray-900 dark:text-gray-100">{appointment.reason}</p>
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Pre-appointment Instructions */}
            {(appointment.status === "pending" || appointment.status === "confirmed") && (
              <Card>
                <CardHeader>
                  <CardTitle as="h3" className="text-base">
                    Pre-appointment Instructions
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <ul className="space-y-3">
                    <li className="flex items-start gap-3">
                      <svg
                        className="w-5 h-5 text-success-500 shrink-0 mt-0.5"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                      <span className="text-gray-700 dark:text-gray-300">
                        Please arrive 10 minutes before your scheduled appointment time.
                      </span>
                    </li>
                    <li className="flex items-start gap-3">
                      <svg
                        className="w-5 h-5 text-success-500 shrink-0 mt-0.5"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                      <span className="text-gray-700 dark:text-gray-300">
                        Bring your insurance card and a valid photo ID.
                      </span>
                    </li>
                    <li className="flex items-start gap-3">
                      <svg
                        className="w-5 h-5 text-success-500 shrink-0 mt-0.5"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                      <span className="text-gray-700 dark:text-gray-300">
                        Prepare a list of any medications you are currently taking.
                      </span>
                    </li>
                    {appointment.consultation_type === "video" && (
                      <li className="flex items-start gap-3">
                        <svg
                          className="w-5 h-5 text-success-500 shrink-0 mt-0.5"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        <span className="text-gray-700 dark:text-gray-300">
                          Ensure you have a stable internet connection and working camera/microphone.
                        </span>
                      </li>
                    )}
                  </ul>
                </CardContent>
              </Card>
            )}

            {/* Patient Notes */}
            <Card>
              <CardHeader>
                <CardTitle as="h3" className="text-base">
                  Your Notes
                </CardTitle>
              </CardHeader>
              <CardContent>
                <textarea
                  value={patientNotes}
                  onChange={(e) => setPatientNotes(e.target.value)}
                  placeholder="Add any notes or questions you want to discuss with your doctor..."
                  className={cn(
                    "w-full rounded-lg border bg-white transition-colors duration-200",
                    "px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm",
                    "text-gray-900 placeholder:text-gray-400",
                    "focus:outline-none focus:ring-2 focus:ring-offset-0",
                    "border-gray-300 hover:border-gray-400",
                    "focus:border-primary-500 focus:ring-primary-500/20",
                    "dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700",
                    "dark:placeholder:text-gray-500 dark:hover:border-gray-600",
                    "dark:focus:border-primary-400",
                    "resize-none"
                  )}
                  rows={4}
                />
                <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
                  These notes are for your personal reference only.
                </p>
              </CardContent>
            </Card>

            {/* Review Section */}
            {appointment.status === "completed" && (
              <Card>
                <CardHeader>
                  <CardTitle as="h3" className="text-base">
                    Your Review
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {existingReview ? (
                    <div className="space-y-4">
                      <div className="flex items-center gap-2">
                        <StarRating rating={existingReview.rating} size="md" />
                        <span className="text-sm text-gray-500 dark:text-gray-400">
                          Reviewed on {new Date(existingReview.created_at).toLocaleDateString()}
                        </span>
                      </div>
                      {existingReview.title && (
                        <p className="font-medium text-gray-900 dark:text-gray-100">
                          {existingReview.title}
                        </p>
                      )}
                      {existingReview.comment && (
                        <p className="text-gray-700 dark:text-gray-300">{existingReview.comment}</p>
                      )}
                    </div>
                  ) : canReview ? (
                    showReviewForm ? (
                      <ReviewForm
                        doctorId={appointment.doctor_id.toString()}
                        appointmentId={appointment.id.toString()}
                        onSubmit={handleReviewSubmit}
                        onCancel={() => setShowReviewForm(false)}
                        isLoading={createReviewMutation.isPending}
                      />
                    ) : (
                      <div className="text-center py-4">
                        <p className="text-gray-600 dark:text-gray-400 mb-4">
                          Share your experience with {doctorName}
                        </p>
                        <Button variant="outline" onClick={() => setShowReviewForm(true)}>
                          Write a Review
                        </Button>
                      </div>
                    )
                  ) : (
                    <p className="text-center text-gray-500 dark:text-gray-400 py-4">
                      {canReviewData?.reason || "Review not available for this appointment."}
                    </p>
                  )}
                </CardContent>
              </Card>
            )}
          </div>

          {/* Right Column - Actions */}
          <div className="space-y-6">
            {/* Actions Card */}
            <Card>
              <CardHeader>
                <CardTitle as="h3" className="text-base">
                  Actions
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                {canJoinVideo && (
                  <Link to={`/video/${appointment.id}`} className="block">
                    <Button variant="primary" fullWidth>
                      <svg className="w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                        />
                      </svg>
                      Join Video Call
                    </Button>
                  </Link>
                )}

                {canCancel && (
                  <>
                    <Button
                      variant="outline"
                      fullWidth
                      disabled
                      className="opacity-60 cursor-not-allowed"
                    >
                      <svg className="w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                        />
                      </svg>
                      Reschedule
                    </Button>
                    <Button
                      variant="outline"
                      fullWidth
                      onClick={handleCancelClick}
                      className="border-error-300 text-error-600 hover:bg-error-50 dark:border-error-700 dark:text-error-400 dark:hover:bg-error-900/20"
                    >
                      <svg className="w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M6 18L18 6M6 6l12 12"
                        />
                      </svg>
                      Cancel Appointment
                    </Button>
                  </>
                )}

                {appointment.status === "completed" && canReview && !showReviewForm && (
                  <Button variant="outline" fullWidth onClick={() => setShowReviewForm(true)}>
                    <svg className="w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                      />
                    </svg>
                    Leave Review
                  </Button>
                )}

                {appointment.status === "cancelled" && (
                  <div className="text-center py-4">
                    <p className="text-gray-500 dark:text-gray-400 text-sm">
                      This appointment has been cancelled.
                    </p>
                    <Link to="/doctors" className="block mt-4">
                      <Button variant="primary" fullWidth>
                        Book New Appointment
                      </Button>
                    </Link>
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Consultation Type Info */}
            <Card>
              <CardContent>
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-lg bg-primary-100 dark:bg-primary-900/40 flex items-center justify-center text-primary-600 dark:text-primary-400">
                    {consultationType.icon}
                  </div>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-gray-100">
                      {consultationType.label}
                    </p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {consultationType.description}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Need Help */}
            <Card>
              <CardContent>
                <h3 className="font-medium text-gray-900 dark:text-gray-100 mb-2">
                  Need Help?
                </h3>
                <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
                  Contact our support team for any questions or assistance.
                </p>
                <Button variant="ghost" fullWidth disabled className="text-sm">
                  <svg className="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Contact Support
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>

      {/* Cancel Confirmation Dialog */}
      <ConfirmDialog
        isOpen={showCancelDialog}
        title="Cancel Appointment"
        message={`Are you sure you want to cancel your appointment with ${doctorName} on ${formatDateForDisplay(appointment.appointment_date)}? This action cannot be undone.`}
        confirmLabel="Yes, Cancel Appointment"
        variant="danger"
        isLoading={cancelMutation.isPending}
        onConfirm={handleConfirmCancel}
        onCancel={handleDialogClose}
      />
    </>
  );
}