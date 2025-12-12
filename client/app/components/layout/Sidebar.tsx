import { NavLink } from "react-router";
import { cn } from "~/lib/utils";

/**
 * Navigation item interface for sidebar links
 */
interface NavItem {
  label: string;
  path: string;
  icon: React.ReactNode;
}

/**
 * Sidebar props interface
 */
interface SidebarProps {
  /** Whether the mobile sidebar is open */
  isOpen: boolean;
  /** Callback to close the sidebar (mobile only) */
  onClose: () => void;
}

/**
 * Navigation items configuration
 */
const navItems: NavItem[] = [
  {
    label: "Dashboard",
    path: "/dashboard",
    icon: (
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
          d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
        />
      </svg>
    ),
  },
  {
    label: "Doctors",
    path: "/doctors",
    icon: (
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
          d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
        />
      </svg>
    ),
  },
  {
    label: "Appointments",
    path: "/appointments",
    icon: (
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
          d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
        />
      </svg>
    ),
  },
  {
    label: "Profile",
    path: "/profile",
    icon: (
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
          d="M5.121 17.804A13.937 13.937 0 0112 16c2.5 0 4.847.655 6.879 1.804M15 10a3 3 0 11-6 0 3 3 0 016 0zm6 2a9 9 0 11-18 0 9 9 0 0118 0z"
        />
      </svg>
    ),
  },
];

/**
 * Sidebar Component
 *
 * Responsive sidebar navigation for the main layout.
 * - Fixed sidebar on desktop (left side, always visible)
 * - Drawer/overlay on mobile (toggled via hamburger menu)
 * - Highlights the active route with visual indicator
 * - Professional medical theme with primary colors
 *
 * @example
 * <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
 */
export function Sidebar({ isOpen, onClose }: SidebarProps) {
  return (
    <>
      {/* Mobile overlay backdrop */}
      <div
        className={cn(
          "fixed inset-0 z-40 bg-gray-900/50 backdrop-blur-sm transition-opacity lg:hidden",
          isOpen ? "opacity-100" : "opacity-0 pointer-events-none"
        )}
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Sidebar container */}
      <aside
        className={cn(
          // Base styles
          "fixed top-0 left-0 z-50 h-full w-64 bg-white dark:bg-gray-900",
          "border-r border-gray-200 dark:border-gray-800",
          "flex flex-col",
          // Mobile: transform-based show/hide
          "transform transition-transform duration-300 ease-in-out lg:transform-none",
          isOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0",
          // Desktop: fixed position
          "lg:z-30"
        )}
        aria-label="Main navigation"
      >
        {/* Logo/Brand section */}
        <div className="flex items-center justify-between h-16 px-4 border-b border-gray-200 dark:border-gray-800">
          <div className="flex items-center gap-3">
            {/* Medical cross icon */}
            <div className="flex items-center justify-center w-9 h-9 rounded-lg bg-primary-600">
              <svg
                className="w-5 h-5 text-white"
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

          {/* Mobile close button */}
          <button
            type="button"
            className="lg:hidden p-2 -mr-2 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            onClick={onClose}
            aria-label="Close sidebar"
          >
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
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        {/* Navigation links */}
        <nav className="flex-1 px-3 py-4 overflow-y-auto">
          <ul className="space-y-1" role="list">
            {navItems.map((item) => (
              <li key={item.path}>
                <NavLink
                  to={item.path}
                  onClick={onClose}
                  className={({ isActive }) =>
                    cn(
                      // Base styles
                      "flex items-center gap-3 px-3 py-2.5 rounded-lg font-medium transition-colors",
                      "min-h-[44px]", // Touch-friendly tap target
                      // Active state
                      isActive
                        ? "bg-primary-50 text-primary-700 dark:bg-primary-900/50 dark:text-primary-300"
                        : "text-gray-700 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
                    )
                  }
                >
                  {({ isActive }) => (
                    <>
                      <span
                        className={cn(
                          isActive
                            ? "text-primary-600 dark:text-primary-400"
                            : "text-gray-500 dark:text-gray-400"
                        )}
                      >
                        {item.icon}
                      </span>
                      <span>{item.label}</span>
                      {/* Active indicator bar */}
                      {isActive && (
                        <span className="ml-auto w-1 h-5 rounded-full bg-primary-600 dark:bg-primary-400" />
                      )}
                    </>
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>

        {/* Bottom section with version/info */}
        <div className="px-4 py-3 border-t border-gray-200 dark:border-gray-800">
          <p className="text-xs text-gray-400 dark:text-gray-500">
            MediConnect v1.0
          </p>
        </div>
      </aside>
    </>
  );
}
