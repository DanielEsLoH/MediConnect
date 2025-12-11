import { useState, useMemo, useCallback } from "react";
import { Link } from "react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

import { Button, Spinner } from "~/components/ui";
import { cn } from "~/lib/utils";
import {
  appointmentsApi,
  AppointmentCard,
  type Appointment,
} from "~/features/appointments";

/**
 * Query keys for appointments.
 */
const appointmentKeys = {
  all: ["appointments"] as const,
  list: () => [...appointmentKeys.all, "list"] as const,
};

/**
 * Check if an appointment is in the past.
 * Past appointments are those with:
 * - Date before today, OR
 * - Status of completed, cancelled, or no_show
 */
function isPastAppointment(appointment: Appointment): boolean {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const appointmentDate = new Date(appointment.appointment_date + "T00:00:00");

  // If date is in the past, it's a past appointment
  if (appointmentDate < today) {
    return true;
  }

  // If status is completed, cancelled, or no_show, it's considered past
  const pastStatuses = ["completed", "cancelled", "no_show"];
  return pastStatuses.includes(appointment.status);
}

/**
 * Sort appointments by date ascending (for upcoming).
 */
function sortByDateAsc(a: Appointment, b: Appointment): number {
  const dateA = new Date(`${a.appointment_date}T${a.start_time}`);
  const dateB = new Date(`${b.appointment_date}T${b.start_time}`);
  return dateA.getTime() - dateB.getTime();
}

/**
 * Sort appointments by date descending (for past).
 */
function sortByDateDesc(a: Appointment, b: Appointment): number {
  const dateA = new Date(`${a.appointment_date}T${a.start_time}`);
  const dateB = new Date(`${b.appointment_date}T${b.start_time}`);
  return dateB.getTime() - dateA.getTime();
}

/**
 * Toast notification component.
 */
interface ToastProps {
  message: string;
  type: "success" | "error";
  onClose: () => void;
}

function Toast({ message, type, onClose }: ToastProps) {
  return (
    <div
      className={cn(
        "fixed bottom-4 right-4 left-4 sm:left-auto sm:w-96 z-50",
        "p-4 rounded-lg shadow-lg",
        "flex items-center gap-3",
        "animate-in slide-in-from-bottom-4 fade-in duration-300",
        type === "success"
          ? "bg-success-600 text-white"
          : "bg-error-600 text-white"
      )}
      role="alert"
      aria-live="polite"
    >
      {type === "success" ? (
        <svg
          className="w-5 h-5 shrink-0"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M5 13l4 4L19 7"
          />
        </svg>
      ) : (
        <svg
          className="w-5 h-5 shrink-0"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      )}
      <p className="flex-1 text-sm font-medium">{message}</p>
      <button
        type="button"
        onClick={onClose}
        className="shrink-0 p-1 rounded hover:bg-white/20 transition-colors"
        aria-label="Close notification"
      >
        <svg
          className="w-4 h-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      </button>
    </div>
  );
}

/**
 * Empty state component for when there are no appointments.
 */
function EmptyState() {
  return (
    <div className="text-center py-12 sm:py-16">
      {/* Calendar icon */}
      <div className="mx-auto w-16 h-16 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 mb-4">
        <svg
          className="w-8 h-8 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
          />
        </svg>
      </div>
      <h2 className="text-lg font-medium text-gray-900 dark:text-gray-100">
        You have no appointments yet
      </h2>
      <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-sm mx-auto">
        Book your first appointment with one of our healthcare professionals.
      </p>
      <Link to="/doctors" className="inline-block mt-6">
        <Button variant="primary">Find a Doctor</Button>
      </Link>
    </div>
  );
}

/**
 * Section empty state for when a specific section has no appointments.
 */
interface SectionEmptyProps {
  title: string;
  message: string;
  icon: "calendar" | "clock";
}

function SectionEmpty({ title, message, icon }: SectionEmptyProps) {
  return (
    <div className="text-center py-8 px-4 bg-gray-50 dark:bg-gray-800/50 rounded-xl">
      {icon === "calendar" ? (
        <svg
          className="mx-auto h-10 w-10 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
          />
        </svg>
      ) : (
        <svg
          className="mx-auto h-10 w-10 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
      )}
      <h3 className="mt-3 text-sm font-medium text-gray-900 dark:text-gray-100">
        {title}
      </h3>
      <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{message}</p>
    </div>
  );
}

/**
 * Error state component.
 */
interface ErrorStateProps {
  message: string;
  onRetry: () => void;
}

function ErrorState({ message, onRetry }: ErrorStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 sm:py-16 text-center">
      <div className="w-16 h-16 rounded-full bg-error-100 dark:bg-error-900/30 flex items-center justify-center mb-4">
        <svg
          className="w-8 h-8 text-error-600 dark:text-error-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
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
        Unable to Load Appointments
      </h2>
      <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">
        {message}
      </p>
      <Button variant="primary" onClick={onRetry} className="mt-6">
        Try Again
      </Button>
    </div>
  );
}

/**
 * Appointments Page Component
 *
 * Displays the user's appointments grouped into upcoming and past sections.
 * Features:
 * - Fetches appointments using TanStack Query
 * - Groups appointments into upcoming and past
 * - Allows cancellation of eligible appointments
 * - Optimistic updates for better UX
 * - Loading, error, and empty states
 * - Responsive grid layout
 */
export default function AppointmentsPage() {
  const queryClient = useQueryClient();
  const [cancellingId, setCancellingId] = useState<number | null>(null);
  const [toast, setToast] = useState<{
    message: string;
    type: "success" | "error";
  } | null>(null);

  // Fetch appointments
  const {
    data: appointments,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: appointmentKeys.list(),
    queryFn: appointmentsApi.getAppointments,
    staleTime: 1000 * 60 * 2, // Consider data fresh for 2 minutes
    retry: 2,
  });

  // Cancel appointment mutation with optimistic update
  const cancelMutation = useMutation({
    mutationFn: (id: number) => appointmentsApi.cancelAppointment(id),
    onMutate: async (id) => {
      setCancellingId(id);

      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey: appointmentKeys.list() });

      // Snapshot the previous value
      const previousAppointments = queryClient.getQueryData<Appointment[]>(
        appointmentKeys.list()
      );

      // Optimistically update to the new value
      if (previousAppointments) {
        queryClient.setQueryData<Appointment[]>(
          appointmentKeys.list(),
          previousAppointments.map((apt) =>
            apt.id === id ? { ...apt, status: "cancelled" as const } : apt
          )
        );
      }

      return { previousAppointments };
    },
    onSuccess: () => {
      setToast({
        message: "Appointment cancelled successfully",
        type: "success",
      });
      // Auto-dismiss toast after 4 seconds
      setTimeout(() => setToast(null), 4000);
    },
    onError: (err, _id, context) => {
      // Revert optimistic update on error
      if (context?.previousAppointments) {
        queryClient.setQueryData(
          appointmentKeys.list(),
          context.previousAppointments
        );
      }

      const message =
        err instanceof Error
          ? err.message
          : "Failed to cancel appointment. Please try again.";
      setToast({ message, type: "error" });
      // Auto-dismiss toast after 5 seconds
      setTimeout(() => setToast(null), 5000);
    },
    onSettled: () => {
      setCancellingId(null);
      // Invalidate to ensure we have fresh data
      queryClient.invalidateQueries({ queryKey: appointmentKeys.list() });
    },
  });

  // Group appointments into upcoming and past
  const { upcomingAppointments, pastAppointments } = useMemo(() => {
    if (!appointments) {
      return { upcomingAppointments: [], pastAppointments: [] };
    }

    const upcoming: Appointment[] = [];
    const past: Appointment[] = [];

    for (const appointment of appointments) {
      if (isPastAppointment(appointment)) {
        past.push(appointment);
      } else {
        upcoming.push(appointment);
      }
    }

    // Sort upcoming by date ascending (soonest first)
    upcoming.sort(sortByDateAsc);
    // Sort past by date descending (most recent first)
    past.sort(sortByDateDesc);

    return { upcomingAppointments: upcoming, pastAppointments: past };
  }, [appointments]);

  // Handle cancel
  const handleCancel = useCallback(
    (id: number) => {
      cancelMutation.mutate(id);
    },
    [cancelMutation]
  );

  // Handle toast close
  const handleToastClose = useCallback(() => {
    setToast(null);
  }, []);

  // Loading state
  if (isLoading) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Your Appointments
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            View and manage your medical appointments.
          </p>
        </div>

        {/* Loading State */}
        <div className="flex items-center justify-center py-16">
          <Spinner size="lg" label="Loading appointments..." />
        </div>
      </>
    );
  }

  // Error state
  if (isError) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Your Appointments
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            View and manage your medical appointments.
          </p>
        </div>

        <ErrorState
          message={
            error instanceof Error
              ? error.message
              : "An error occurred while loading your appointments."
          }
          onRetry={() => refetch()}
        />
      </>
    );
  }

  // Empty state - no appointments at all
  const hasNoAppointments =
    !appointments ||
    (upcomingAppointments.length === 0 && pastAppointments.length === 0);

  if (hasNoAppointments) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Your Appointments
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            View and manage your medical appointments.
          </p>
        </div>

        <EmptyState />
      </>
    );
  }

  return (
    <>
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Your Appointments
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          View and manage your medical appointments.
        </p>
      </div>

      {/* Upcoming Appointments Section */}
      <section className="mb-10" aria-labelledby="upcoming-heading">
        <div className="flex items-center justify-between mb-4">
          <h2
            id="upcoming-heading"
            className="text-lg sm:text-xl font-semibold text-gray-900 dark:text-gray-100"
          >
            Upcoming Appointments
            {upcomingAppointments.length > 0 && (
              <span className="ml-2 text-sm font-normal text-gray-500 dark:text-gray-400">
                ({upcomingAppointments.length})
              </span>
            )}
          </h2>
          <Link to="/doctors">
            <Button variant="outline" size="sm">
              Book New
            </Button>
          </Link>
        </div>

        {upcomingAppointments.length > 0 ? (
          <div className="grid gap-4 sm:gap-6 md:grid-cols-2">
            {upcomingAppointments.map((appointment) => (
              <AppointmentCard
                key={appointment.id}
                appointment={appointment}
                onCancel={handleCancel}
                isCancelling={cancellingId === appointment.id}
              />
            ))}
          </div>
        ) : (
          <SectionEmpty
            title="No Upcoming Appointments"
            message="You don't have any scheduled appointments."
            icon="calendar"
          />
        )}
      </section>

      {/* Past Appointments Section */}
      <section aria-labelledby="past-heading">
        <h2
          id="past-heading"
          className="text-lg sm:text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4"
        >
          Past Appointments
          {pastAppointments.length > 0 && (
            <span className="ml-2 text-sm font-normal text-gray-500 dark:text-gray-400">
              ({pastAppointments.length})
            </span>
          )}
        </h2>

        {pastAppointments.length > 0 ? (
          <div className="grid gap-4 sm:gap-6 md:grid-cols-2">
            {pastAppointments.map((appointment) => (
              <AppointmentCard
                key={appointment.id}
                appointment={appointment}
              />
            ))}
          </div>
        ) : (
          <SectionEmpty
            title="No Past Appointments"
            message="Your appointment history will appear here."
            icon="clock"
          />
        )}
      </section>

      {/* Toast Notification */}
      {toast && (
        <Toast
          message={toast.message}
          type={toast.type}
          onClose={handleToastClose}
        />
      )}
    </>
  );
}
