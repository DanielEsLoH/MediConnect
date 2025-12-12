import type { ConsultationType } from "~/features/appointments";

/**
 * Booking step identifiers for the 6-step booking flow.
 */
export type BookingStep =
  | "date_time"
  | "consultation_type"
  | "reason"
  | "personal_data"
  | "payment"
  | "confirmation";

/**
 * User personal data for step 4 (confirmation/editing).
 */
export interface PersonalData {
  /** User's full name */
  full_name: string;
  /** User's email address */
  email: string;
  /** User's phone number */
  phone: string;
}

/**
 * Complete booking state managed throughout the 6-step flow.
 */
export interface BookingState {
  // Step 1: Date & Time
  /** Selected appointment date (YYYY-MM-DD format) */
  selectedDate: string | null;
  /** Selected start time (HH:mm format) */
  startTime: string | null;
  /** Selected end time (HH:mm format) */
  endTime: string | null;

  // Step 2: Consultation Type
  /** Selected consultation type */
  consultationType: ConsultationType | null;

  // Step 3: Reason & Symptoms
  /** Patient's reason for appointment */
  reason: string;

  // Step 4: Personal Data
  /** User's personal information */
  personalData: PersonalData | null;

  // Step 5: Payment
  /** Stripe payment intent client secret */
  paymentClientSecret: string | null;
  /** Internal payment ID */
  paymentId: number | null;
  /** Stripe payment intent ID (after successful payment) */
  stripePaymentIntentId: string | null;

  // Step 6: Confirmation
  /** Created appointment ID (after successful booking) */
  appointmentId: number | null;

  // Navigation
  /** Current active step */
  currentStep: BookingStep;
  /** Steps that have been completed */
  completedSteps: BookingStep[];
}

/**
 * Props for step components.
 */
export interface StepComponentProps {
  /** Doctor ID for the appointment */
  doctorId: number;
  /** Consultation fee for the doctor */
  consultationFee: number;
  /** Callback to proceed to next step */
  onNext: () => void;
  /** Callback to go back to previous step */
  onBack?: () => void;
}

/**
 * Step configuration metadata.
 */
export interface StepConfig {
  /** Unique identifier */
  id: BookingStep;
  /** Step number (1-6) */
  number: number;
  /** Display title */
  title: string;
  /** Brief description */
  description: string;
  /** Whether this step can be skipped */
  optional?: boolean;
}
