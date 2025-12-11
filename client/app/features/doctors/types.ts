/**
 * Doctor entity type representing a healthcare professional.
 */
export interface Doctor {
  /** Unique identifier for the doctor */
  id: number;
  /** Full name of the doctor */
  full_name: string;
  /** Medical specialty (e.g., "Cardiology", "Pediatrics") */
  specialty: string;
  /** Years of professional experience */
  years_of_experience: number;
  /** Consultation fee in dollars */
  consultation_fee: number;
  /** Brief biography or description */
  bio: string | null;
  /** Average rating from patient reviews (0-5) */
  rating: number | null;
  /** Total number of patient reviews */
  total_reviews: number;
}

/**
 * Parameters for searching/filtering doctors.
 */
export interface DoctorSearchParams {
  /** Search term for doctor name */
  search?: string;
  /** Filter by medical specialty */
  specialty?: string;
  /** Current page number for pagination */
  page?: number;
  /** Number of results per page */
  per_page?: number;
}

/**
 * Pagination metadata from the API response.
 */
export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
}

/**
 * API response structure for paginated doctor list.
 */
export interface DoctorsResponse {
  data: Doctor[];
  meta: PaginationMeta;
}
