import { useCallback } from "react";
import { useSearchParams } from "react-router";
import { useQuery } from "@tanstack/react-query";

import { Spinner } from "~/components/ui";
import {
  doctorsApi,
  DoctorCard,
  DoctorFilters,
  type DoctorSearchParams,
} from "~/features/doctors";

/**
 * Query key factory for doctors queries.
 * Ensures consistent cache key generation for TanStack Query.
 */
const doctorsKeys = {
  all: ["doctors"] as const,
  list: (params: DoctorSearchParams) => [...doctorsKeys.all, "list", params] as const,
};

/**
 * Doctors Page Component
 *
 * Displays a searchable, filterable list of healthcare professionals.
 * Features:
 * - Search by doctor name with debounced input
 * - Filter by medical specialty
 * - URL synchronization for shareable filter states
 * - Responsive grid layout (1/2/3 columns)
 * - Loading, empty, and error states
 */
export default function DoctorsPage() {
  const [searchParams, setSearchParams] = useSearchParams();

  // Extract filter values from URL params
  const search = searchParams.get("search") || "";
  const specialty = searchParams.get("specialty") || "";

  // Build query params object
  const queryParams: DoctorSearchParams = {
    ...(search && { search }),
    ...(specialty && { specialty }),
  };

  // Fetch doctors with TanStack Query
  const {
    data,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: doctorsKeys.list(queryParams),
    queryFn: () => doctorsApi.getDoctors(queryParams),
    staleTime: 1000 * 60 * 5, // Consider data fresh for 5 minutes
  });

  // Update URL params when filters change
  const updateSearchParams = useCallback(
    (key: string, value: string) => {
      setSearchParams((prev) => {
        const newParams = new URLSearchParams(prev);
        if (value) {
          newParams.set(key, value);
        } else {
          newParams.delete(key);
        }
        return newParams;
      });
    },
    [setSearchParams]
  );

  // Handle search change
  const handleSearchChange = useCallback(
    (value: string) => {
      updateSearchParams("search", value);
    },
    [updateSearchParams]
  );

  // Handle specialty change
  const handleSpecialtyChange = useCallback(
    (value: string) => {
      updateSearchParams("specialty", value);
    },
    [updateSearchParams]
  );

  // Clear all filters
  const handleClearFilters = useCallback(() => {
    setSearchParams(new URLSearchParams());
  }, [setSearchParams]);

  const doctors = data?.data || [];
  const hasResults = doctors.length > 0;

  return (
    <>
      {/* Page Header */}
      <div className="mb-6 sm:mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Find a Doctor
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Browse our network of healthcare professionals and find the right
          doctor for your needs.
        </p>
      </div>

      {/* Filters */}
      <DoctorFilters
        search={search}
        specialty={specialty}
        onSearchChange={handleSearchChange}
        onSpecialtyChange={handleSpecialtyChange}
        onClearFilters={handleClearFilters}
        className="mb-6 sm:mb-8"
      />

      {/* Loading State */}
      {isLoading && (
        <div className="flex flex-col items-center justify-center py-16">
          <Spinner size="lg" label="Loading doctors" />
          <p className="mt-4 text-sm text-gray-500 dark:text-gray-400">
            Loading doctors...
          </p>
        </div>
      )}

      {/* Error State */}
      {isError && (
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
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">
            Unable to Load Doctors
          </h3>
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">
            {error instanceof Error
              ? error.message
              : "An error occurred while fetching the doctors list. Please try again."}
          </p>
          <button
            type="button"
            onClick={() => refetch()}
            className="mt-4 inline-flex items-center px-4 py-2 text-sm font-medium text-primary-600 hover:text-primary-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 dark:text-primary-400"
          >
            <svg
              className="w-4 h-4 mr-1.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
              />
            </svg>
            Try Again
          </button>
        </div>
      )}

      {/* Empty State */}
      {!isLoading && !isError && !hasResults && (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <div className="w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-4">
            <svg
              className="w-8 h-8 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.5}
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
          </div>
          <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">
            No Doctors Found
          </h3>
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">
            {search || specialty
              ? "No doctors match your current filters. Try adjusting your search criteria."
              : "There are no doctors available at the moment. Please check back later."}
          </p>
          {(search || specialty) && (
            <button
              type="button"
              onClick={handleClearFilters}
              className="mt-4 text-sm font-medium text-primary-600 hover:text-primary-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 dark:text-primary-400"
            >
              Clear all filters
            </button>
          )}
        </div>
      )}

      {/* Doctors Grid */}
      {!isLoading && !isError && hasResults && (
        <>
          {/* Results count */}
          <p className="mb-4 text-sm text-gray-500 dark:text-gray-400">
            Showing {doctors.length} doctor{doctors.length !== 1 ? "s" : ""}
            {data?.meta?.total_count && data.meta.total_count > doctors.length && (
              <> of {data.meta.total_count}</>
            )}
          </p>

          {/* Grid */}
          <div className="grid gap-4 sm:gap-6 md:grid-cols-2 lg:grid-cols-3">
            {doctors.map((doctor) => (
              <DoctorCard key={doctor.id} doctor={doctor} />
            ))}
          </div>
        </>
      )}
    </>
  );
}
