import { useNavigate } from "react-router";
import { useMutation } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { authApi } from "~/features/auth/api/auth-api";
import { useAuthStore } from "~/store/useAuthStore";
import { Button } from "~/components/ui";
import { NotificationBell } from "~/components/notifications/NotificationBell";
import { cn } from "~/lib/utils";

/**
 * Header props interface
 */
interface HeaderProps {
  /** Callback to toggle the mobile sidebar */
  onMenuToggle: () => void;
}

/**
 * Header Component
 *
 * Top navigation header for the main layout.
 * - Displays user info (name/email) from auth state
 * - Logout button that clears auth state and redirects to login
 * - Mobile hamburger menu toggle button (only visible on mobile)
 * - Responsive design with Tailwind CSS
 *
 * @example
 * <Header onMenuToggle={() => setSidebarOpen(true)} />
 */
export function Header({ onMenuToggle }: HeaderProps) {
  const navigate = useNavigate();
  const { user, logout: storeLogout } = useAuthStore();

  // Logout mutation with server-side logout
  const logoutMutation = useMutation({
    mutationFn: authApi.logout,
    onSuccess: () => {
      storeLogout();
      toast.success("You have been logged out successfully.");
      navigate("/login");
    },
    onError: () => {
      // Even if server logout fails, clear local state
      storeLogout();
      toast.success("You have been logged out.");
      navigate("/login");
    },
  });

  const handleLogout = () => {
    logoutMutation.mutate();
  };

  // Get user initials for avatar
  const getUserInitials = () => {
    if (!user) return "?";
    const first = user.first_name?.[0] || "";
    const last = user.last_name?.[0] || "";
    return (first + last).toUpperCase() || user.email[0].toUpperCase();
  };

  return (
    <header
      className={cn(
        "sticky top-0 z-20",
        "h-16 bg-white dark:bg-gray-900",
        "border-b border-gray-200 dark:border-gray-800",
        "flex items-center justify-between",
        "px-4 lg:px-6"
      )}
    >
      {/* Left section: Mobile menu button and breadcrumb area */}
      <div className="flex items-center gap-3">
        {/* Mobile hamburger menu button */}
        <button
          type="button"
          className={cn(
            "lg:hidden",
            "p-2 -ml-2 text-gray-500 hover:text-gray-700",
            "dark:text-gray-400 dark:hover:text-gray-200",
            "rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800",
            "transition-colors",
            "min-h-[44px] min-w-[44px] flex items-center justify-center" // Touch-friendly
          )}
          onClick={onMenuToggle}
          aria-label="Open sidebar menu"
        >
          <svg
            className="w-6 h-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>

        {/* Mobile logo - shown on small screens when sidebar is hidden */}
        <div className="lg:hidden flex items-center gap-2">
          <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary-600">
            <svg
              className="w-4 h-4 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 6v6m0 0v6m0-6h6m-6 0H6"
              />
            </svg>
          </div>
          <span className="text-lg font-bold text-primary-600 dark:text-primary-400">
            MediConnect
          </span>
        </div>
      </div>

      {/* Right section: Notifications, user info, and logout */}
      <div className="flex items-center gap-2 sm:gap-4">
        {/* Notification bell */}
        <NotificationBell />

        {/* Divider - visible on larger screens */}
        <div className="hidden sm:block h-6 w-px bg-gray-200 dark:bg-gray-700" />

        {/* User info - hidden on very small screens */}
        <div className="hidden sm:flex items-center gap-3">
          {/* User avatar */}
          <div
            className={cn(
              "flex items-center justify-center",
              "w-9 h-9 rounded-full",
              "bg-primary-100 dark:bg-primary-900",
              "text-primary-700 dark:text-primary-300",
              "text-sm font-semibold"
            )}
            aria-hidden="true"
          >
            {getUserInitials()}
          </div>

          {/* User name and email */}
          <div className="hidden md:block text-right">
            <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
              {user?.first_name} {user?.last_name}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {user?.email}
            </p>
          </div>
        </div>

        {/* Logout button */}
        <Button
          variant="outline"
          size="sm"
          onClick={handleLogout}
          isLoading={logoutMutation.isPending}
          loadingText="Logging out"
          className="whitespace-nowrap"
        >
          <svg
            className="w-4 h-4 mr-1.5 hidden sm:block"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
            />
          </svg>
          <span className="hidden sm:inline">Logout</span>
          <span className="sm:hidden">
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
              />
            </svg>
          </span>
        </Button>
      </div>
    </header>
  );
}
