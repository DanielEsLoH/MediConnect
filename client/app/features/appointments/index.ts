// Appointments Feature Module
// Export all appointment-related API functions and types

// API
export { appointmentsApi } from "./api/appointments-api";

// Components
export { AppointmentCard } from "./components/AppointmentCard";

// Types
export type {
  Appointment,
  AppointmentDoctor,
  AppointmentStatus,
  ConsultationType,
  CreateAppointmentPayload,
  CreateAppointmentResponse,
  TimeSlot,
} from "./types";
