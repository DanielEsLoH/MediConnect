import { useEffect } from "react";
import { useBookingStore } from "../store/bookingStore";
import type { BookingStep, StepConfig } from "../types";
import { cn } from "~/lib/utils";

/**
 * Step configurations for the booking flow.
 */
const STEP_CONFIGS: StepConfig[] = [
  {
    id: "date_time",
    number: 1,
    title: "Date & Time",
    description: "Select your preferred appointment slot",
  },
  {
    id: "consultation_type",
    number: 2,
    title: "Consultation Type",
    description: "Choose how you'd like to consult",
  },
  {
    id: "reason",
    number: 3,
    title: "Reason",
    description: "Tell us why you're booking",
    optional: true,
  },
  {
    id: "personal_data",
    number: 4,
    title: "Confirm Details",
    description: "Review your personal information",
  },
  {
    id: "payment",
    number: 5,
    title: "Payment",
    description: "Complete your booking payment",
  },
  {
    id: "confirmation",
    number: 6,
    title: "Confirmation",
    description: "Your appointment is booked",
  },
];

export interface BookingStepperProps {
  /** Doctor ID for the appointment */
  doctorId: number;
  /** Doctor's full name */
  doctorName: string;
  /** Consultation fee */
  consultationFee: number;
  /** Children render prop to render step content */
  children: (stepId: BookingStep) => React.ReactNode;
  /** Callback when booking is completed */
  onComplete?: (appointmentId: number) => void;
}

/**
 * Progress Indicator Component
 * Displays the 6 steps with visual indicators of completion status.
 */
function ProgressIndicator({
  currentStep,
  completedSteps,
  onStepClick,
}: {
  currentStep: BookingStep;
  completedSteps: BookingStep[];
  onStepClick: (step: BookingStep) => void;
}) {
  return (
    <nav aria-label="Progress" className="mb-8">
      <ol className="flex items-center justify-between">
        {STEP_CONFIGS.map((step, index) => {
          const isActive = currentStep === step.id;
          const isCompleted = completedSteps.includes(step.id);
          const isClickable = isCompleted || isActive;

          return (
            <li key={step.id} className="relative flex-1">
              {/* Connector Line (except for last step) */}
              {index < STEP_CONFIGS.length - 1 && (
                <div
                  className={cn(
                    "absolute top-5 left-1/2 w-full h-0.5 -translate-y-1/2",
                    "hidden sm:block",
                    isCompleted ? "bg-primary-600" : "bg-gray-300 dark:bg-gray-700"
                  )}
                  aria-hidden="true"
                />
              )}

              {/* Step Button */}
              <button
                type="button"
                onClick={() => isClickable && onStepClick(step.id)}
                disabled={!isClickable}
                className={cn(
                  "relative flex flex-col items-center group",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2 rounded-lg",
                  isClickable ? "cursor-pointer" : "cursor-not-allowed"
                )}
                aria-current={isActive ? "step" : undefined}
              >
                {/* Circle */}
                <div
                  className={cn(
                    "w-10 h-10 flex items-center justify-center rounded-full border-2 transition-all duration-200",
                    "text-sm font-semibold relative z-10 bg-white dark:bg-gray-900",
                    isActive &&
                      "border-primary-600 text-primary-600 dark:border-primary-400 dark:text-primary-400 ring-4 ring-primary-100 dark:ring-primary-900/50",
                    isCompleted &&
                      !isActive &&
                      "border-primary-600 bg-primary-600 text-white dark:border-primary-500 dark:bg-primary-500",
                    !isActive &&
                      !isCompleted &&
                      "border-gray-300 text-gray-500 dark:border-gray-700 dark:text-gray-500"
                  )}
                >
                  {isCompleted && !isActive ? (
                    <svg
                      className="w-5 h-5"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                      aria-hidden="true"
                    >
                      <path
                        fillRule="evenodd"
                        d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                        clipRule="evenodd"
                      />
                    </svg>
                  ) : (
                    step.number
                  )}
                </div>

                {/* Label (Hidden on mobile for space) */}
                <div className="mt-2 text-center hidden sm:block">
                  <p
                    className={cn(
                      "text-xs font-medium",
                      isActive
                        ? "text-primary-600 dark:text-primary-400"
                        : isCompleted
                          ? "text-gray-900 dark:text-gray-100"
                          : "text-gray-500 dark:text-gray-500"
                    )}
                  >
                    {step.title}
                  </p>
                </div>
              </button>
            </li>
          );
        })}
      </ol>

      {/* Mobile Step Title */}
      <div className="mt-4 sm:hidden text-center">
        <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
          Step {STEP_CONFIGS.find((s) => s.id === currentStep)?.number}:{" "}
          {STEP_CONFIGS.find((s) => s.id === currentStep)?.title}
        </p>
        <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
          {STEP_CONFIGS.find((s) => s.id === currentStep)?.description}
        </p>
      </div>
    </nav>
  );
}

/**
 * Main BookingStepper Component
 *
 * Orchestrates the 6-step booking flow with:
 * - Visual progress indicator
 * - Step navigation (next/back/jump)
 * - State management via Zustand
 * - Completion callback
 *
 * @example
 * <BookingStepper
 *   doctorId={123}
 *   doctorName="Dr. Smith"
 *   consultationFee={150}
 *   onComplete={(appointmentId) => navigate(`/appointments/${appointmentId}`)}
 * >
 *   {(stepId) => {
 *     switch (stepId) {
 *       case 'date_time': return <DateTimeStep ... />;
 *       case 'consultation_type': return <ConsultationTypeStep ... />;
 *       // ... other steps
 *     }
 *   }}
 * </BookingStepper>
 */
export function BookingStepper({
  doctorId,
  doctorName,
  consultationFee,
  children,
  onComplete,
}: BookingStepperProps) {
  const { currentStep, completedSteps, appointmentId, goToStep, resetBooking } =
    useBookingStore();

  // Call onComplete when appointment is created
  useEffect(() => {
    if (appointmentId && currentStep === "confirmation" && onComplete) {
      onComplete(appointmentId);
    }
  }, [appointmentId, currentStep, onComplete]);

  // Reset booking on unmount (cleanup)
  useEffect(() => {
    return () => {
      resetBooking();
    };
  }, [resetBooking]);

  return (
    <div className="w-full max-w-4xl mx-auto">
      {/* Doctor Context Header */}
      <div className="mb-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Booking appointment with
            </p>
            <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">
              {doctorName}
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Consultation Fee
            </p>
            <p className="text-lg font-bold text-primary-600 dark:text-primary-400">
              ${consultationFee}
            </p>
          </div>
        </div>
      </div>

      {/* Progress Indicator */}
      <ProgressIndicator
        currentStep={currentStep}
        completedSteps={completedSteps}
        onStepClick={goToStep}
      />

      {/* Current Step Content */}
      <div className="bg-white dark:bg-gray-900 rounded-xl shadow-sm border border-gray-200 dark:border-gray-800 p-6 sm:p-8">
        {/* Desktop Step Header */}
        <div className="hidden sm:block mb-6">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
            {STEP_CONFIGS.find((s) => s.id === currentStep)?.title}
          </h2>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
            {STEP_CONFIGS.find((s) => s.id === currentStep)?.description}
          </p>
        </div>

        {/* Step Content (Rendered via children render prop) */}
        {children(currentStep)}
      </div>
    </div>
  );
}
