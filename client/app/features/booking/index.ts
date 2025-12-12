// Booking Feature Module
// Export all booking-related components, hooks, and types

// Components
export { BookingStepper } from "./components/BookingStepper";

// Steps
export { DateTimeStep } from "./components/steps/DateTimeStep";
export { ConsultationTypeStep } from "./components/steps/ConsultationTypeStep";
export { ReasonStep } from "./components/steps/ReasonStep";
export { PersonalDataStep } from "./components/steps/PersonalDataStep";
export { PaymentStep } from "./components/steps/PaymentStep";
export { ConfirmationStep } from "./components/steps/ConfirmationStep";

// Store
export { useBookingStore } from "./store/bookingStore";

// Types
export type {
  BookingStep,
  BookingState,
  PersonalData,
  StepComponentProps,
  StepConfig,
} from "./types";
