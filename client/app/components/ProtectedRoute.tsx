import { Navigate, useLocation } from 'react-router';
import type { ReactNode } from 'react';
import { useAuthStore } from '~/store/useAuthStore';
import { Spinner } from '~/components/ui';

interface ProtectedRouteProps {
  children: ReactNode;
  /** Optional: Redirect path when not authenticated. Defaults to /login */
  redirectTo?: string;
}

/**
 * ProtectedRoute Component
 *
 * Wrapper component that ensures users are authenticated before
 * accessing protected pages. Redirects to login if not authenticated.
 *
 * @example
 * <ProtectedRoute>
 *   <DashboardPage />
 * </ProtectedRoute>
 */
export function ProtectedRoute({
  children,
  redirectTo = '/login',
}: ProtectedRouteProps) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const location = useLocation();

  // Show loading state while hydrating from localStorage
  // This prevents flash of login page on refresh
  if (typeof window !== 'undefined' && !isAuthenticated) {
    // Check if we're still hydrating
    const stored = localStorage.getItem('mediconnect-auth');
    if (stored) {
      const parsed = JSON.parse(stored);
      if (parsed?.state?.isAuthenticated) {
        // Still hydrating, show spinner
        return (
          <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950">
            <Spinner size="lg" center label="Loading..." />
          </div>
        );
      }
    }
  }

  // Redirect to login if not authenticated
  if (!isAuthenticated) {
    // Save the attempted URL to redirect back after login
    return <Navigate to={redirectTo} state={{ from: location }} replace />;
  }

  // Render protected content
  return <>{children}</>;
}
