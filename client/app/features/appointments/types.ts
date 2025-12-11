/**
 * Embedded doctor information in appointment responses.
 */
export interface AppointmentDoctor {
  /** Doctor's unique identifier */
  id: number;
  /** Doctor's full name */
  full_name: string;
  /** Doctor's medical specialty */
  specialty: string;
}

/**
 * Appointment entity type representing a scheduled medical appointment.
 */
export interface Appointment {
  /** Unique identifier for the appointment */
  id: number;
  /** ID of the doctor for this appointment */
  doctor_id: number;
  /** ID of the patient */
  patient_id: number;
  /** Date of the appointment (YYYY-MM-DD format) */
  appointment_date: string;
  /** Start time of the appointment (HH:mm format) */
  start_time: string;
  /** End time of the appointment (HH:mm format) */
  end_time: string;
  /** Type of consultation */
  consultation_type: ConsultationType;
  /** Patient's reason for the appointment */
  reason: string | null;
  /** Current status of the appointment */
  status: AppointmentStatus;
  /** Timestamp when the appointment was created */
  created_at: string;
  /** Timestamp when the appointment was last updated */
  updated_at: string;
  /** Embedded doctor information (optional, depends on API response) */
  doctor?: AppointmentDoctor;
}

/**
 * Available consultation types.
 */
export type ConsultationType = "in_person" | "video" | "phone";

/**
 * Available appointment statuses.
 */
export type AppointmentStatus =
  | "pending"
  | "confirmed"
  | "completed"
  | "cancelled"
  | "no_show";

/**
 * Payload for creating a new appointment.
 */
export interface CreateAppointmentPayload {
  appointment: {
    /** ID of the doctor to book with */
    doctor_id: number;
    /** Date of the appointment (YYYY-MM-DD format) */
    appointment_date: string;
    /** Start time of the appointment (HH:mm format) */
    start_time: string;
    /** End time of the appointment (HH:mm format) */
    end_time: string;
    /** Type of consultation */
    consultation_type: ConsultationType;
    /** Patient's reason for the appointment (optional) */
    reason?: string;
  };
}

/**
 * API response structure for appointment creation.
 */
export interface CreateAppointmentResponse {
  data: Appointment;
  message?: string;
}

/**
 * Time slot representation for booking UI.
 */
export interface TimeSlot {
  /** Start time of the slot (HH:mm format) */
  start_time: string;
  /** End time of the slot (HH:mm format) */
  end_time: string;
  /** Whether the slot is available for booking */
  available: boolean;
}
