import { useParams, useNavigate, Link } from "react-router";
import { useQuery } from "@tanstack/react-query";

import { Spinner } from "~/components/ui";
import { doctorsApi } from "~/features/doctors";
import {
  BookingStepper,
  DateTimeStep,
  ConsultationTypeStep,
  ReasonStep,
  PersonalDataStep,
  PaymentStep,
  ConfirmationStep,
  useBookingStore,
  type BookingStep,
} from "~/features/booking";

/**
 * Query key factory for doctor queries.
 */
const doctorKeys = {
  all: ["doctors"] as const,
  detail: (id: number) => [...doctorKeys.all, "detail", id] as const,
};

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
        <button
          onClick={onRetry}
          className="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"
        >
          Try Again
        </button>
        <Link
          to="/doctors"
          className="px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
        >
          Back to Doctors
        </Link>
      </div>
    </div>
  );
}

/**
 * Doctor Booking Page Component
 *
 * Provides a dedicated page for booking appointments with a doctor using
 * the 6-step BookingStepper wizard.
 *
 * Route: /doctors/:id/book
 */
export default function DoctorBookingPage() {
  const { id } = useParams();
  const navigate = useNavigate();

  // Parse the doctor ID
  const doctorId = id ? parseInt(id, 10) : NaN;

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

  // Get booking store methods
  const { nextStep, previousStep } = useBookingStore();

  // Handle completion
  const handleComplete = (appointmentId: number) => {
    // Navigate to appointment detail page after confirmation
    setTimeout(() => {
      navigate(`/appointments/${appointmentId}`);
    }, 3000);
  };

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
      <div className="flex flex-col items-center justify-center py-16">
        <Spinner size="lg" />
        <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">
          Loading doctor information...
        </p>
      </div>
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

  // Render step content based on current step
  const renderStepContent = (stepId: BookingStep) => {
    switch (stepId) {
      case "date_time":
        return <DateTimeStep doctorId={doctor.id} onNext={nextStep} />;

      case "consultation_type":
        return (
          <ConsultationTypeStep
            consultationFee={doctor.consultation_fee}
            onNext={nextStep}
            onBack={previousStep}
          />
        );

      case "reason":
        return <ReasonStep onNext={nextStep} onBack={previousStep} />;

      case "personal_data":
        return <PersonalDataStep onNext={nextStep} onBack={previousStep} />;

      case "payment":
        return (
          <PaymentStep
            doctorId={doctor.id}
            consultationFee={doctor.consultation_fee}
            onNext={nextStep}
            onBack={previousStep}
          />
        );

      case "confirmation":
        return (
          <ConfirmationStep
            doctorName={doctor.full_name}
            doctorSpecialty={doctor.specialty}
            consultationFee={doctor.consultation_fee}
          />
        );

      default:
        return null;
    }
  };

  return (
    <div className="max-w-5xl mx-auto py-8">
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
            <Link
              to={`/doctor-detail/${doctor.id}`}
              className="text-gray-500 hover:text-primary-600 dark:text-gray-400 dark:hover:text-primary-400 transition-colors"
            >
              {doctor.full_name}
            </Link>
          </li>
          <li>
            <span className="text-gray-400" aria-hidden="true">
              /
            </span>
          </li>
          <li>
            <span className="text-gray-900 dark:text-gray-100 font-medium">
              Book Appointment
            </span>
          </li>
        </ol>
      </nav>

      {/* Booking Stepper */}
      <BookingStepper
        doctorId={doctor.id}
        doctorName={doctor.full_name}
        consultationFee={doctor.consultation_fee}
        onComplete={handleComplete}
      >
        {renderStepContent}
      </BookingStepper>
    </div>
  );
}
