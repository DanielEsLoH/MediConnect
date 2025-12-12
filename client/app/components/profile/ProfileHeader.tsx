import type { User } from "~/types/auth";
import { cn } from "~/lib/utils";

interface ProfileHeaderProps {
  /** User data to display */
  user: User;
  /** Additional CSS classes */
  className?: string;
}

/**
 * ProfileHeader Component
 *
 * Displays user avatar, full name, and email (read-only).
 * Features a professional medical-themed design with:
 * - Initials-based avatar with gradient background
 * - Full name prominently displayed
 * - Email shown in muted text
 * - Role badge for context
 * - Responsive sizing (smaller on mobile)
 *
 * @example
 * <ProfileHeader user={currentUser} />
 */
export function ProfileHeader({ user, className }: ProfileHeaderProps) {
  // Generate initials from first and last name
  const initials = `${user.first_name?.charAt(0) || ""}${user.last_name?.charAt(0) || ""}`.toUpperCase();

  // Get display name
  const fullName = `${user.first_name || ""} ${user.last_name || ""}`.trim() || "User";

  // Format role for display (capitalize first letter)
  const displayRole = user.role
    ? user.role.charAt(0).toUpperCase() + user.role.slice(1).toLowerCase()
    : "Patient";

  return (
    <div
      className={cn(
        "flex flex-col items-center text-center",
        "p-6 sm:p-8",
        className
      )}
    >
      {/* Avatar with initials */}
      <div
        className={cn(
          "flex items-center justify-center",
          "w-20 h-20 sm:w-24 sm:h-24",
          "rounded-full",
          "bg-gradient-to-br from-primary-500 to-primary-700",
          "shadow-lg shadow-primary-500/25",
          "mb-4"
        )}
        role="img"
        aria-label={`${fullName}'s avatar`}
      >
        <span className="text-2xl sm:text-3xl font-bold text-white">
          {initials || "U"}
        </span>
      </div>

      {/* Name */}
      <h2 className="text-xl sm:text-2xl font-bold text-gray-900 dark:text-gray-100">
        {fullName}
      </h2>

      {/* Email (read-only) */}
      <p className="mt-1 text-sm sm:text-base text-gray-500 dark:text-gray-400">
        {user.email}
      </p>

      {/* Role badge */}
      <span
        className={cn(
          "mt-3 inline-flex items-center",
          "px-3 py-1 rounded-full",
          "text-xs sm:text-sm font-medium",
          "bg-primary-100 text-primary-700",
          "dark:bg-primary-900/50 dark:text-primary-300"
        )}
      >
        {displayRole}
      </span>

      {/* Member since info */}
      {user.created_at && (
        <p className="mt-4 text-xs text-gray-400 dark:text-gray-500">
          Member since{" "}
          {new Date(user.created_at).toLocaleDateString("en-US", {
            month: "long",
            year: "numeric",
          })}
        </p>
      )}
    </div>
  );
}
