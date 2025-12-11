import api from "~/lib/api";
import type { Doctor, DoctorSearchParams, DoctorsResponse } from "../types";

/**
 * Doctors API service.
 * Handles all doctor-related API calls: list and detail retrieval.
 */
export const doctorsApi = {
  /**
   * Get a paginated list of doctors with optional filters.
   * @param params - Search and pagination parameters
   * @returns Paginated list of doctors with metadata
   */
  getDoctors: async (params?: DoctorSearchParams): Promise<DoctorsResponse> => {
    const response = await api.get<DoctorsResponse>("/doctors", { params });
    return response.data;
  },

  /**
   * Get a single doctor by ID.
   * @param id - Doctor's unique identifier
   * @returns Doctor details
   */
  getDoctorById: async (id: number): Promise<Doctor> => {
    const response = await api.get<Doctor>(`/doctors/${id}`);
    return response.data;
  },
};
