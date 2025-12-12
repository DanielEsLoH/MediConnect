import { create } from "zustand";
import type { BookingState, BookingStep, PersonalData } from "../types";
import type { ConsultationType } from "~/features/appointments";

/**
 * Get today's date in YYYY-MM-DD format.
 */
function getTodayDate(): string {
  return new Date().toISOString().split("T")[0];
}

/**
 * Step order for navigation.
 */
const STEP_ORDER: BookingStep[] = [
  "date_time",
  "consultation_type",
  "reason",
  "personal_data",
  "payment",
  "confirmation",
];

/**
 * Initial booking state.
 */
const initialState: BookingState = {
  // Step 1
  selectedDate: getTodayDate(),
  startTime: null,
  endTime: null,

  // Step 2
  consultationType: null,

  // Step 3
  reason: "",

  // Step 4
  personalData: null,

  // Step 5
  paymentClientSecret: null,
  paymentId: null,
  stripePaymentIntentId: null,

  // Step 6
  appointmentId: null,

  // Navigation
  currentStep: "date_time",
  completedSteps: [],
};

/**
 * Booking store actions.
 */
interface BookingActions {
  // Step 1: Date & Time
  setDateTime: (date: string, startTime: string, endTime: string) => void;

  // Step 2: Consultation Type
  setConsultationType: (type: ConsultationType) => void;

  // Step 3: Reason
  setReason: (reason: string) => void;

  // Step 4: Personal Data
  setPersonalData: (data: PersonalData) => void;

  // Step 5: Payment
  setPaymentIntent: (clientSecret: string, paymentId: number) => void;
  setPaymentSuccess: (stripePaymentIntentId: string) => void;

  // Step 6: Confirmation
  setAppointmentId: (id: number) => void;

  // Navigation
  goToStep: (step: BookingStep) => void;
  nextStep: () => void;
  previousStep: () => void;
  markStepComplete: (step: BookingStep) => void;
  canProceedToStep: (step: BookingStep) => boolean;

  // Reset
  resetBooking: () => void;
}

/**
 * Booking store type combining state and actions.
 */
type BookingStore = BookingState & BookingActions;

/**
 * Zustand store for managing booking flow state.
 *
 * Handles all state management for the 6-step booking process:
 * 1. Date & Time Selection
 * 2. Consultation Type Selection
 * 3. Reason & Symptoms
 * 4. Personal Data Confirmation
 * 5. Payment
 * 6. Confirmation
 *
 * @example
 * const { currentStep, setDateTime, nextStep } = useBookingStore();
 *
 * // Update date/time and proceed
 * setDateTime('2025-12-15', '10:00', '10:30');
 * nextStep();
 */
export const useBookingStore = create<BookingStore>((set, get) => ({
  ...initialState,

  // Step 1: Date & Time
  setDateTime: (date, startTime, endTime) =>
    set({
      selectedDate: date,
      startTime,
      endTime,
    }),

  // Step 2: Consultation Type
  setConsultationType: (type) =>
    set({
      consultationType: type,
    }),

  // Step 3: Reason
  setReason: (reason) =>
    set({
      reason,
    }),

  // Step 4: Personal Data
  setPersonalData: (data) =>
    set({
      personalData: data,
    }),

  // Step 5: Payment
  setPaymentIntent: (clientSecret, paymentId) =>
    set({
      paymentClientSecret: clientSecret,
      paymentId,
    }),

  setPaymentSuccess: (stripePaymentIntentId) =>
    set({
      stripePaymentIntentId,
    }),

  // Step 6: Confirmation
  setAppointmentId: (id) =>
    set({
      appointmentId: id,
    }),

  // Navigation
  goToStep: (step) => {
    const state = get();
    if (state.canProceedToStep(step)) {
      set({ currentStep: step });
    }
  },

  nextStep: () => {
    const state = get();
    const currentIndex = STEP_ORDER.indexOf(state.currentStep);
    if (currentIndex < STEP_ORDER.length - 1) {
      const nextStep = STEP_ORDER[currentIndex + 1];
      state.markStepComplete(state.currentStep);
      set({ currentStep: nextStep });
    }
  },

  previousStep: () => {
    const state = get();
    const currentIndex = STEP_ORDER.indexOf(state.currentStep);
    if (currentIndex > 0) {
      const previousStep = STEP_ORDER[currentIndex - 1];
      set({ currentStep: previousStep });
    }
  },

  markStepComplete: (step) =>
    set((state) => ({
      completedSteps: state.completedSteps.includes(step)
        ? state.completedSteps
        : [...state.completedSteps, step],
    })),

  canProceedToStep: (targetStep) => {
    const state = get();
    const targetIndex = STEP_ORDER.indexOf(targetStep);
    const currentIndex = STEP_ORDER.indexOf(state.currentStep);

    // Can always go back
    if (targetIndex < currentIndex) {
      return true;
    }

    // Can go forward only if previous steps are completed
    if (targetIndex === currentIndex + 1) {
      return validateStepCompletion(state, state.currentStep);
    }

    // Can jump forward only if all intermediate steps are completed
    if (targetIndex > currentIndex + 1) {
      for (let i = currentIndex; i < targetIndex; i++) {
        const step = STEP_ORDER[i];
        if (!validateStepCompletion(state, step)) {
          return false;
        }
      }
      return true;
    }

    return true;
  },

  // Reset
  resetBooking: () => set({ ...initialState }),
}));

/**
 * Validate if a step has all required data to proceed.
 */
function validateStepCompletion(state: BookingState, step: BookingStep): boolean {
  switch (step) {
    case "date_time":
      return !!(state.selectedDate && state.startTime && state.endTime);

    case "consultation_type":
      return !!state.consultationType;

    case "reason":
      // Reason is optional, so always valid
      return true;

    case "personal_data":
      return !!(
        state.personalData &&
        state.personalData.full_name &&
        state.personalData.email &&
        state.personalData.phone
      );

    case "payment":
      return !!state.stripePaymentIntentId;

    case "confirmation":
      return !!state.appointmentId;

    default:
      return false;
  }
}
