import { useState } from "react";
import { Navigate, Outlet, useLocation } from "react-router";

import { useAuthStore } from "~/store/useAuthStore";
import { Spinner } from "~/components/ui";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { cn } from "~/lib/utils";

/**
 * MainLayout Component
 *
 * Protected route wrapper that provides the main application layout.
 * - Checks authentication state and redirects to /login if not authenticated
 * - Combines Sidebar and Header components
 * - Renders children (page content) in the main content area
 * - Responsive layout that works on mobile and desktop
 * - Manages mobile sidebar state
 *
 * @example
 * // In routes.ts, wrap protected routes with layout:
 * route("dashboard", "routes/dashboard.tsx", { layout: MainLayout })
 */
export function MainLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const location = useLocation();

  // Handle loading state while hydrating from localStorage
  // This prevents flash of login page on refresh
  if (typeof window !== "undefined" && !isAuthenticated) {
    // Check if we're still hydrating from localStorage
    const stored = localStorage.getItem("mediconnect-auth");
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        if (parsed?.state?.isAuthenticated) {
          // Still hydrating, show loading spinner
          return (
            <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950">
              <Spinner size="lg" center label="Loading..." />
            </div>
          );
        }
      } catch {
        // Invalid JSON in storage, continue to redirect
      }
    }
  }

  // Redirect to login if not authenticated
  if (!isAuthenticated) {
    // Save the attempted URL to redirect back after login
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  const handleSidebarOpen = () => setSidebarOpen(true);
  const handleSidebarClose = () => setSidebarOpen(false);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950">
      {/* Sidebar navigation */}
      <Sidebar isOpen={sidebarOpen} onClose={handleSidebarClose} />

      {/* Main content area - offset by sidebar width on desktop */}
      <div className="lg:pl-64 flex flex-col min-h-screen">
        {/* Header */}
        <Header onMenuToggle={handleSidebarOpen} />

        {/* Page content */}
        <main
          className={cn(
            "flex-1",
            "px-4 py-6 sm:px-6 lg:px-8",
            "max-w-7xl w-full mx-auto"
          )}
        >
          <Outlet />
        </main>

        {/* Footer */}
        <footer className="px-4 py-4 sm:px-6 lg:px-8 border-t border-gray-200 dark:border-gray-800">
          <p className="text-center text-xs text-gray-500 dark:text-gray-400">
            &copy; {new Date().getFullYear()} MediConnect. All rights reserved.
          </p>
        </footer>
      </div>
    </div>
  );
}
