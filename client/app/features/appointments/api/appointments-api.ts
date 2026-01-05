import api from "~/lib/api";
import type { Appointment, CreateAppointmentPayload } from "../types";

/**
 * Appointments API service.
 * Handles all appointment-related API calls: creation, listing, and management.
 */
export const appointmentsApi = {
  /**
   * Create a new appointment.
   * @param payload - Appointment creation payload with doctor, date, time, and details
   * @returns Created appointment data
   */
  createAppointment: async (
    payload: CreateAppointmentPayload
  ): Promise<Appointment> => {
    const response = await api.post<{ appointment: Appointment }>(
      "/appointments",
      payload
    );
    return response.data.appointment;
  },

  /**
   * Get all appointments for the current user.
   * @returns List of appointments
   */
  getAppointments: async (): Promise<Appointment[]> => {
    const response = await api.get<{ appointments: Appointment[] }>("/appointments");
    return response.data.appointments ?? [];
  },

  /**
   * Get a single appointment by ID.
   * @param id - Appointment's unique identifier
   * @returns Appointment details
   */
  getAppointmentById: async (id: number): Promise<Appointment> => {
    const response = await api.get<{ appointment: Appointment }>(`/appointments/${id}`);
    return response.data.appointment;
  },

  /**
   * Cancel an appointment.
   * @param id - Appointment's unique identifier
   * @returns Updated appointment with cancelled status
   */
  cancelAppointment: async (id: number): Promise<Appointment> => {
    const response = await api.patch<{ appointment: Appointment }>(
      `/appointments/${id}/cancel`
    );
    return response.data.appointment;
  },
};
