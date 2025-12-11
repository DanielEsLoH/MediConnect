import { Link } from "react-router";
import { Card, CardContent, Button } from "~/components/ui";
import { cn } from "~/lib/utils";
import type { Doctor } from "../types";

export interface DoctorCardProps {
  /** Doctor data to display */
  doctor: Doctor;
  /** Additional CSS classes for the card */
  className?: string;
}

/**
 * Get initials from a full name.
 * @param name - Full name string
 * @returns Two-letter initials (e.g., "John Doe" -> "JD")
 */
function getInitials(name: string): string {
  const parts = name.split(" ").filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

/**
 * Format currency value.
 * @param amount - Amount in dollars
 * @returns Formatted string (e.g., "$150")
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

/**
 * DoctorCard component displays a doctor's information in a card layout.
 * Includes avatar with initials, name, specialty, experience, fee, and booking action.
 *
 * @example
 * <DoctorCard doctor={doctorData} />
 */
export function DoctorCard({ doctor, className }: DoctorCardProps) {
  const initials = getInitials(doctor.full_name);

  return (
    <Card
      hover
      className={cn("flex flex-col h-full", className)}
      padding="none"
    >
      <CardContent className="flex flex-col h-full p-4 sm:p-5">
        {/* Doctor Info Header */}
        <div className="flex items-start gap-4">
          {/* Avatar with Initials */}
          <div
            className={cn(
              "shrink-0 w-14 h-14 sm:w-16 sm:h-16",
              "flex items-center justify-center",
              "rounded-full bg-primary-100 dark:bg-primary-900",
              "text-primary-700 dark:text-primary-300",
              "text-lg sm:text-xl font-semibold"
            )}
            aria-hidden="true"
          >
            {initials}
          </div>

          {/* Name and Specialty */}
          <div className="flex-1 min-w-0">
            <h3 className="text-base sm:text-lg font-semibold text-gray-900 dark:text-gray-100 truncate">
              {doctor.full_name}
            </h3>
            <p className="mt-0.5 text-sm text-primary-600 dark:text-primary-400 font-medium">
              {doctor.specialty}
            </p>

            {/* Rating (if available) */}
            {doctor.rating !== null && (
              <div className="mt-1 flex items-center gap-1">
                <svg
                  className="w-4 h-4 text-amber-400"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                  aria-hidden="true"
                >
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  {doctor.rating.toFixed(1)}
                  <span className="text-gray-400 dark:text-gray-500">
                    {" "}
                    ({doctor.total_reviews} reviews)
                  </span>
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Bio (if available) */}
        {doctor.bio && (
          <p className="mt-3 text-sm text-gray-600 dark:text-gray-400 line-clamp-2">
            {doctor.bio}
          </p>
        )}

        {/* Details Grid */}
        <div className="mt-4 grid grid-cols-2 gap-3">
          <div className="flex flex-col">
            <span className="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wide">
              Experience
            </span>
            <span className="mt-0.5 text-sm font-medium text-gray-900 dark:text-gray-100">
              {doctor.years_of_experience} years
            </span>
          </div>
          <div className="flex flex-col">
            <span className="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wide">
              Consultation
            </span>
            <span className="mt-0.5 text-sm font-medium text-gray-900 dark:text-gray-100">
              {formatCurrency(doctor.consultation_fee)}
            </span>
          </div>
        </div>

        {/* Action Button - pushed to bottom */}
        <div className="mt-auto pt-4">
          <Link to={`/doctors/${doctor.id}`}>
            <Button variant="primary" fullWidth>
              Book Appointment
            </Button>
          </Link>
        </div>
      </CardContent>
    </Card>
  );
}
