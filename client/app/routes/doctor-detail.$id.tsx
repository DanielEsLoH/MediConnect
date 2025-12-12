import { useState, useMemo, useCallback } from "react";
import { useParams, useNavigate, Link } from "react-router";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

import { Card, CardContent, Button, Spinner } from "~/components/ui";
import { cn } from "~/lib/utils";
import { doctorsApi, type Doctor } from "~/features/doctors";
import {
  appointmentsApi,
  type CreateAppointmentPayload,
  type ConsultationType,
  type TimeSlot,
} from "~/features/appointments";

/**
 * Query key factory for doctor queries.
 */
const doctorKeys = {
  all: ["doctors"] as const,
  detail: (id: number) => [...doctorKeys.all, "detail", id] as const,
};

/**
 * Generate time slots for a given date.
 * Creates 30-minute slots from 09:00 to 17:00.
 *
 * @param selectedDate - The date to generate slots for
 * @returns Array of time slot objects
 */
function generateTimeSlots(selectedDate: string): TimeSlot[] {
  const slots: TimeSlot[] = [];
  const startHour = 9; // 09:00
  const endHour = 17; // 17:00

  for (let hour = startHour; hour < endHour; hour++) {
    // First half hour slot
    slots.push({
      start_time: `${hour.toString().padStart(2, "0")}:00`,
      end_time: `${hour.toString().padStart(2, "0")}:30`,
      available: true,
    });

    // Second half hour slot
    slots.push({
      start_time: `${hour.toString().padStart(2, "0")}:30`,
      end_time: `${(hour + 1).toString().padStart(2, "0")}:00`,
      available: true,
    });
  }

  return slots;
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
 * Format currency value.
 * @param amount - Amount in dollars
 * @returns Formatted string (e.g., "$150")
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
 * Get today's date in YYYY-MM-DD format.
 */
function getTodayDate(): string {
  return new Date().toISOString().split("T")[0];
}

/**
 * Format a date string for display.
 * @param dateString - Date in YYYY-MM-DD format
 * @returns Formatted date (e.g., "December 15, 2025")
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

// ============================================================================
// Sub-components
// ============================================================================

interface DoctorHeroProps {
  doctor: Doctor;
}

/**
 * Hero section displaying doctor's main information.
 */
function DoctorHero({ doctor }: DoctorHeroProps) {
  const initials = getInitials(doctor.full_name);

  return (
    <div className="bg-gradient-to-br from-primary-50 to-primary-100 dark:from-primary-950 dark:to-primary-900 rounded-2xl p-6 sm:p-8">
      <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6">
        {/* Large Avatar */}
        <div
          className={cn(
            "shrink-0 w-24 h-24 sm:w-28 sm:h-28",
            "flex items-center justify-center",
            "rounded-full bg-white dark:bg-gray-800",
            "text-primary-600 dark:text-primary-400",
            "text-3xl sm:text-4xl font-bold",
            "shadow-lg ring-4 ring-primary-200 dark:ring-primary-800"
          )}
          aria-hidden="true"
        >
          {initials}
        </div>

        {/* Doctor Info */}
        <div className="flex-1 text-center sm:text-left">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            {doctor.full_name}
          </h1>

          {/* Specialty Badge */}
          <span className="inline-block mt-2 px-3 py-1 bg-primary-600 text-white text-sm font-medium rounded-full">
            {doctor.specialty}
          </span>

          {/* Rating */}
          {doctor.rating !== null && (
            <div className="mt-3 flex items-center justify-center sm:justify-start gap-1.5">
              <svg
                className="w-5 h-5 text-amber-400"
                fill="currentColor"
                viewBox="0 0 20 20"
                aria-hidden="true"
              >
                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
              </svg>
              <span className="text-lg font-semibold text-gray-900 dark:text-gray-100">
                {doctor.rating.toFixed(1)}
              </span>
              <span className="text-gray-500 dark:text-gray-400">
                ({doctor.total_reviews} reviews)
              </span>
            </div>
          )}

          {/* Consultation Fee */}
          <div className="mt-4 flex items-center justify-center sm:justify-start gap-2">
            <span className="text-gray-500 dark:text-gray-400">
              Consultation Fee:
            </span>
            <span className="text-2xl font-bold text-primary-600 dark:text-primary-400">
              {formatCurrency(doctor.consultation_fee)}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

interface DoctorAboutProps {
  doctor: Doctor;
}

/**
 * About section with doctor's bio and experience.
 */
function DoctorAbout({ doctor }: DoctorAboutProps) {
  return (
    <Card>
      <CardContent className="p-6">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4">
          About
        </h2>

        {/* Bio */}
        {doctor.bio ? (
          <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
            {doctor.bio}
          </p>
        ) : (
          <p className="text-gray-400 dark:text-gray-500 italic">
            No biography available.
          </p>
        )}

        {/* Experience and Details */}
        <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* Years of Experience */}
          <div className="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="w-10 h-10 flex items-center justify-center bg-primary-100 dark:bg-primary-900 rounded-lg">
              <svg
                className="w-5 h-5 text-primary-600 dark:text-primary-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"
                />
              </svg>
            </div>
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                Experience
              </p>
              <p className="font-semibold text-gray-900 dark:text-gray-100">
                {doctor.years_of_experience} years
              </p>
            </div>
          </div>

          {/* Specialty */}
          <div className="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="w-10 h-10 flex items-center justify-center bg-secondary-100 dark:bg-secondary-900 rounded-lg">
              <svg
                className="w-5 h-5 text-secondary-600 dark:text-secondary-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
                />
              </svg>
            </div>
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                Specialization
              </p>
              <p className="font-semibold text-gray-900 dark:text-gray-100">
                {doctor.specialty}
              </p>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

interface BookingCardProps {
  doctor: Doctor;
  selectedDate: string;
  selectedSlot: TimeSlot | null;
  consultationType: ConsultationType;
  isBooking: boolean;
  onDateChange: (date: string) => void;
  onSlotSelect: (slot: TimeSlot) => void;
  onConsultationTypeChange: (type: ConsultationType) => void;
  onConfirmBooking: () => void;
}

/**
 * Booking card component with date picker and time slots.
 */
function BookingCard({
  doctor,
  selectedDate,
  selectedSlot,
  consultationType,
  isBooking,
  onDateChange,
  onSlotSelect,
  onConsultationTypeChange,
  onConfirmBooking,
}: BookingCardProps) {
  const timeSlots = useMemo(
    () => generateTimeSlots(selectedDate),
    [selectedDate]
  );

  // Calculate minimum date (today)
  const minDate = getTodayDate();

  // Calculate maximum date (30 days from now)
  const maxDate = useMemo(() => {
    const date = new Date();
    date.setDate(date.getDate() + 30);
    return date.toISOString().split("T")[0];
  }, []);

  return (
    <Card className="lg:sticky lg:top-6">
      <CardContent className="p-6">
        <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-6">
          Book Appointment
        </h2>

        {/* Date Selector */}
        <div className="mb-6">
          <label
            htmlFor="appointment-date"
            className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
          >
            Select Date
          </label>
          <input
            type="date"
            id="appointment-date"
            value={selectedDate}
            min={minDate}
            max={maxDate}
            onChange={(e) => onDateChange(e.target.value)}
            disabled={isBooking}
            className={cn(
              "w-full rounded-lg border bg-white transition-colors duration-200",
              "px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm",
              "min-h-[44px] sm:min-h-[40px]",
              "text-gray-900 dark:text-gray-100",
              "border-gray-300 dark:border-gray-700",
              "hover:border-gray-400 dark:hover:border-gray-600",
              "focus:outline-none focus:ring-2 focus:ring-primary-500/20 focus:border-primary-500",
              "dark:bg-gray-900",
              "disabled:opacity-60 disabled:cursor-not-allowed"
            )}
            aria-describedby="date-helper"
          />
          <p id="date-helper" className="mt-1.5 text-sm text-gray-500 dark:text-gray-400">
            {formatDateForDisplay(selectedDate)}
          </p>
        </div>

        {/* Consultation Type */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Consultation Type
          </label>
          <div className="grid grid-cols-3 gap-2">
            {(["in_person", "video", "phone"] as ConsultationType[]).map(
              (type) => (
                <button
                  key={type}
                  type="button"
                  disabled={isBooking}
                  onClick={() => onConsultationTypeChange(type)}
                  className={cn(
                    "py-2 px-3 text-sm font-medium rounded-lg transition-colors",
                    "min-h-[44px] sm:min-h-[40px]",
                    "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
                    "disabled:opacity-60 disabled:cursor-not-allowed",
                    consultationType === type
                      ? "bg-primary-600 text-white"
                      : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
                  )}
                  aria-pressed={consultationType === type}
                >
                  {type === "in_person" && "In Person"}
                  {type === "video" && "Video"}
                  {type === "phone" && "Phone"}
                </button>
              )
            )}
          </div>
        </div>

        {/* Time Slots */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Available Time Slots
          </label>
          <div
            className="grid grid-cols-3 sm:grid-cols-4 gap-2"
            role="group"
            aria-label="Available time slots"
          >
            {timeSlots.map((slot) => {
              const isSelected =
                selectedSlot?.start_time === slot.start_time &&
                selectedSlot?.end_time === slot.end_time;

              return (
                <button
                  key={slot.start_time}
                  type="button"
                  disabled={!slot.available || isBooking}
                  onClick={() => onSlotSelect(slot)}
                  className={cn(
                    "py-2 px-2 text-sm font-medium rounded-lg transition-all duration-200",
                    "min-h-[44px] sm:min-h-[40px]",
                    "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
                    slot.available
                      ? isSelected
                        ? "bg-primary-600 text-white shadow-md scale-105"
                        : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-primary-100 dark:hover:bg-primary-900 hover:text-primary-700 dark:hover:text-primary-300"
                      : "bg-gray-50 dark:bg-gray-900 text-gray-400 dark:text-gray-600 cursor-not-allowed"
                  )}
                  aria-pressed={isSelected}
                  aria-label={`${slot.start_time} to ${slot.end_time}${!slot.available ? ", unavailable" : ""}`}
                >
                  {slot.start_time}
                </button>
              );
            })}
          </div>
        </div>

        {/* Selected Summary */}
        {selectedSlot && (
          <div className="mb-6 p-4 bg-primary-50 dark:bg-primary-950 rounded-lg">
            <h3 className="text-sm font-medium text-primary-900 dark:text-primary-100 mb-2">
              Booking Summary
            </h3>
            <div className="space-y-1 text-sm text-primary-700 dark:text-primary-300">
              <p>
                <span className="font-medium">Doctor:</span> {doctor.full_name}
              </p>
              <p>
                <span className="font-medium">Date:</span>{" "}
                {formatDateForDisplay(selectedDate)}
              </p>
              <p>
                <span className="font-medium">Time:</span> {selectedSlot.start_time} -{" "}
                {selectedSlot.end_time}
              </p>
              <p>
                <span className="font-medium">Type:</span>{" "}
                {consultationType === "in_person" ? "In Person" : consultationType === "video" ? "Video Call" : "Phone Call"}
              </p>
              <p className="pt-2 border-t border-primary-200 dark:border-primary-800">
                <span className="font-medium">Fee:</span>{" "}
                <span className="text-lg font-bold">
                  {formatCurrency(doctor.consultation_fee)}
                </span>
              </p>
            </div>
          </div>
        )}

        {/* Confirm Button */}
        <Button
          variant="primary"
          fullWidth
          disabled={!selectedSlot || isBooking}
          isLoading={isBooking}
          loadingText="Booking..."
          onClick={onConfirmBooking}
        >
          Confirm Booking
        </Button>

        {!selectedSlot && (
          <p className="mt-3 text-center text-sm text-gray-500 dark:text-gray-400">
            Please select a time slot to continue
          </p>
        )}
      </CardContent>
    </Card>
  );
}

/**
 * Loading skeleton for doctor detail page.
 */
function DoctorDetailSkeleton() {
  return (
    <div className="animate-pulse">
      {/* Hero Skeleton */}
      <div className="bg-gray-200 dark:bg-gray-800 rounded-2xl h-64 mb-8" />

      {/* Content Grid Skeleton */}
      <div className="grid gap-6 lg:grid-cols-[1fr,400px]">
        {/* Left Column */}
        <div className="space-y-6">
          <div className="bg-gray-200 dark:bg-gray-800 rounded-xl h-48" />
        </div>

        {/* Right Column */}
        <div className="bg-gray-200 dark:bg-gray-800 rounded-xl h-96" />
      </div>
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
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="w-16 h-16 rounded-full bg-error-100 dark:bg-error-900 flex items-center justify-center mb-4">
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
        Unable to Load Doctor
      </h2>
      <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">
        {message}
      </p>
      <div className="mt-6 flex gap-4">
        <Button variant="primary" onClick={onRetry}>
          Try Again
        </Button>
        <Link to="/doctors">
          <Button variant="outline">Back to Doctors</Button>
        </Link>
      </div>
    </div>
  );
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

// ============================================================================
// Main Component
// ============================================================================

/**
 * Doctor Detail Page Component
 *
 * Displays comprehensive doctor information and appointment booking interface.
 * Features:
 * - Doctor profile with avatar, specialty, rating, and fee
 * - About section with bio and experience
 * - Interactive booking card with date picker and time slots
 * - Responsive layout (stacked on mobile, side-by-side on desktop)
 * - Loading, error, and success states
 * - Toast notifications for booking feedback
 */
export default function DoctorDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  // Parse the doctor ID
  const doctorId = id ? parseInt(id, 10) : NaN;

  // Local state for booking
  const [selectedDate, setSelectedDate] = useState(getTodayDate);
  const [selectedSlot, setSelectedSlot] = useState<TimeSlot | null>(null);
  const [consultationType, setConsultationType] =
    useState<ConsultationType>("in_person");
  const [toast, setToast] = useState<{
    message: string;
    type: "success" | "error";
  } | null>(null);

  // Fetch doctor details
  const {
    data: doctor,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: doctorKeys.detail(doctorId),
    queryFn: () => doctorsApi.getDoctorById(doctorId),
    enabled: !isNaN(doctorId),
    staleTime: 1000 * 60 * 5, // Consider data fresh for 5 minutes
    retry: 2,
  });

  // Booking mutation
  const bookingMutation = useMutation({
    mutationFn: (payload: CreateAppointmentPayload) =>
      appointmentsApi.createAppointment(payload),
    onSuccess: () => {
      // Invalidate appointments query
      queryClient.invalidateQueries({ queryKey: ["appointments"] });

      // Show success toast
      setToast({
        message: "Appointment booked successfully!",
        type: "success",
      });

      // Navigate to appointments page after delay
      setTimeout(() => {
        navigate("/appointments");
      }, 1500);
    },
    onError: (err) => {
      // Show error toast
      const message =
        err instanceof Error
          ? err.message
          : "Failed to book appointment. Please try again.";
      setToast({ message, type: "error" });

      // Reset booking state
      setSelectedSlot(null);
    },
  });

  // Handle date change - reset selected slot
  const handleDateChange = useCallback((date: string) => {
    setSelectedDate(date);
    setSelectedSlot(null);
  }, []);

  // Handle slot selection
  const handleSlotSelect = useCallback((slot: TimeSlot) => {
    setSelectedSlot(slot);
  }, []);

  // Handle consultation type change
  const handleConsultationTypeChange = useCallback((type: ConsultationType) => {
    setConsultationType(type);
  }, []);

  // Handle booking confirmation
  const handleConfirmBooking = useCallback(() => {
    if (!doctor || !selectedSlot) return;

    const payload: CreateAppointmentPayload = {
      appointment: {
        doctor_id: doctor.id,
        appointment_date: selectedDate,
        start_time: selectedSlot.start_time,
        end_time: selectedSlot.end_time,
        consultation_type: consultationType,
        reason: "", // Optional - could add a reason input field
      },
    };

    bookingMutation.mutate(payload);
  }, [doctor, selectedDate, selectedSlot, consultationType, bookingMutation]);

  // Handle toast close
  const handleToastClose = useCallback(() => {
    setToast(null);
  }, []);

  // Handle invalid doctor ID
  if (isNaN(doctorId)) {
    return (
      <ErrorState
        message="Invalid doctor ID provided."
        onRetry={() => navigate("/doctors")}
      />
    );
  }

  // Loading state
  if (isLoading) {
    return (
      <>
        {/* Breadcrumb */}
        <nav className="mb-6" aria-label="Breadcrumb">
          <ol className="flex items-center gap-2 text-sm">
            <li>
              <Link
                to="/doctors"
                className="text-gray-500 hover:text-primary-600 dark:text-gray-400 dark:hover:text-primary-400 transition-colors"
              >
                Doctors
              </Link>
            </li>
            <li>
              <span className="text-gray-400" aria-hidden="true">
                /
              </span>
            </li>
            <li>
              <span className="text-gray-900 dark:text-gray-100">Loading...</span>
            </li>
          </ol>
        </nav>

        <DoctorDetailSkeleton />
      </>
    );
  }

  // Error state
  if (isError || !doctor) {
    return (
      <ErrorState
        message={
          error instanceof Error
            ? error.message
            : "Unable to find the requested doctor."
        }
        onRetry={() => refetch()}
      />
    );
  }

  return (
    <>
      {/* Breadcrumb */}
      <nav className="mb-6" aria-label="Breadcrumb">
        <ol className="flex items-center gap-2 text-sm">
          <li>
            <Link
              to="/doctors"
              className="text-gray-500 hover:text-primary-600 dark:text-gray-400 dark:hover:text-primary-400 transition-colors"
            >
              Doctors
            </Link>
          </li>
          <li>
            <span className="text-gray-400" aria-hidden="true">
              /
            </span>
          </li>
          <li>
            <span className="text-gray-900 dark:text-gray-100 font-medium">
              {doctor.full_name}
            </span>
          </li>
        </ol>
      </nav>

      {/* Hero Section */}
      <DoctorHero doctor={doctor} />

      {/* Main Content - Responsive Grid */}
      <div className="mt-8 grid gap-6 lg:grid-cols-[1fr,400px]">
        {/* Left Column - About */}
        <div className="order-2 lg:order-1">
          <DoctorAbout doctor={doctor} />
        </div>

        {/* Right Column - Booking Card */}
        <div className="order-1 lg:order-2">
          <Card className="lg:sticky lg:top-6">
            <CardContent className="p-6">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-4">
                Book Appointment
              </h2>

              {/* Fee Display */}
              <div className="mb-6 p-4 bg-primary-50 dark:bg-primary-950 rounded-lg">
                <div className="flex items-center justify-between">
                  <span className="text-sm text-primary-700 dark:text-primary-300">
                    Consultation Fee
                  </span>
                  <span className="text-2xl font-bold text-primary-900 dark:text-primary-100">
                    {formatCurrency(doctor.consultation_fee)}
                  </span>
                </div>
              </div>

              {/* Features List */}
              <ul className="space-y-3 mb-6">
                <li className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <svg className="w-5 h-5 text-success-600 dark:text-success-400 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span>Choose your preferred time slot</span>
                </li>
                <li className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <svg className="w-5 h-5 text-success-600 dark:text-success-400 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span>In-person, video, or phone consultation</span>
                </li>
                <li className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <svg className="w-5 h-5 text-success-600 dark:text-success-400 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span>Secure payment with Stripe</span>
                </li>
                <li className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <svg className="w-5 h-5 text-success-600 dark:text-success-400 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                  <span>Instant confirmation</span>
                </li>
              </ul>

              {/* Book Button */}
              <Link to={`/doctors/${doctor.id}/book`} className="block">
                <Button variant="primary" fullWidth>
                  Book Appointment
                </Button>
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>

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
