import { useState, useEffect, useId } from "react";
import { Input, Button } from "~/components/ui";
import { cn } from "~/lib/utils";

/**
 * Custom hook for debouncing a value.
 * @param value - Value to debounce
 * @param delay - Debounce delay in milliseconds
 * @returns Debounced value
 */
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(timer);
    };
  }, [value, delay]);

  return debouncedValue;
}

/**
 * Available medical specialties for filtering.
 */
const SPECIALTIES = [
  "General Practice",
  "Cardiology",
  "Dermatology",
  "Endocrinology",
  "Gastroenterology",
  "Neurology",
  "Oncology",
  "Orthopedics",
  "Pediatrics",
  "Psychiatry",
  "Pulmonology",
  "Rheumatology",
  "Urology",
] as const;

export interface DoctorFiltersProps {
  /** Current search value */
  search: string;
  /** Current specialty filter */
  specialty: string;
  /** Callback when search value changes (debounced) */
  onSearchChange: (value: string) => void;
  /** Callback when specialty filter changes */
  onSpecialtyChange: (value: string) => void;
  /** Callback to clear all filters */
  onClearFilters: () => void;
  /** Additional CSS classes */
  className?: string;
}

/**
 * DoctorFilters component provides search and filter controls for the doctors list.
 * Includes a debounced search input and specialty dropdown.
 *
 * @example
 * <DoctorFilters
 *   search={search}
 *   specialty={specialty}
 *   onSearchChange={setSearch}
 *   onSpecialtyChange={setSpecialty}
 *   onClearFilters={handleClear}
 * />
 */
export function DoctorFilters({
  search,
  specialty,
  onSearchChange,
  onSpecialtyChange,
  onClearFilters,
  className,
}: DoctorFiltersProps) {
  // Local state for immediate input updates
  const [searchInput, setSearchInput] = useState(search);
  const debouncedSearch = useDebounce(searchInput, 300);

  // Generate unique IDs for accessibility
  const selectId = useId();

  // Sync local search input with prop changes (e.g., URL navigation)
  useEffect(() => {
    setSearchInput(search);
  }, [search]);

  // Trigger callback when debounced search changes
  useEffect(() => {
    if (debouncedSearch !== search) {
      onSearchChange(debouncedSearch);
    }
  }, [debouncedSearch, onSearchChange, search]);

  const hasFilters = search || specialty;

  return (
    <div
      className={cn(
        "flex flex-col gap-3 sm:flex-row sm:items-end sm:gap-4",
        className
      )}
    >
      {/* Search Input */}
      <div className="flex-1 sm:max-w-sm">
        <Input
          label="Search"
          type="search"
          placeholder="Search by name..."
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          aria-label="Search doctors by name"
        />
      </div>

      {/* Specialty Select */}
      <div className="w-full sm:w-48">
        <label
          htmlFor={selectId}
          className="block text-sm font-medium mb-1.5 text-gray-700 dark:text-gray-300"
        >
          Specialty
        </label>
        <select
          id={selectId}
          value={specialty}
          onChange={(e) => onSpecialtyChange(e.target.value)}
          className={cn(
            // Base styles
            "w-full rounded-lg border bg-white transition-colors duration-200",
            // Responsive padding
            "px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm",
            // Min height for touch accessibility
            "min-h-11 sm:min-h-10",
            // Text styles
            "text-gray-900",
            // Border and focus styles
            "border-gray-300",
            "hover:border-gray-400",
            "focus:outline-none focus:ring-2 focus:ring-offset-0",
            "focus:border-primary-500 focus:ring-primary-500/20",
            // Dark mode
            "dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700",
            "dark:hover:border-gray-600",
            "dark:focus:border-primary-400"
          )}
          aria-label="Filter by specialty"
        >
          <option value="">All Specialties</option>
          {SPECIALTIES.map((spec) => (
            <option key={spec} value={spec}>
              {spec}
            </option>
          ))}
        </select>
      </div>

      {/* Clear Filters Button */}
      {hasFilters && (
        <div className="sm:pb-0.5">
          <Button
            variant="ghost"
            size="sm"
            onClick={onClearFilters}
            aria-label="Clear all filters"
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
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
            Clear Filters
          </Button>
        </div>
      )}
    </div>
  );
}
