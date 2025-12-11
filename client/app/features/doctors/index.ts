// Doctors Feature Module
// Export all doctors-related components, API functions, and types

// API
export { doctorsApi } from "./api/doctors-api";

// Components
export { DoctorCard } from "./components/DoctorCard";
export type { DoctorCardProps } from "./components/DoctorCard";

export { DoctorFilters } from "./components/DoctorFilters";
export type { DoctorFiltersProps } from "./components/DoctorFilters";

// Types
export type {
  Doctor,
  DoctorSearchParams,
  DoctorsResponse,
  PaginationMeta,
} from "./types";
