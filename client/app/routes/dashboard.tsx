import { useNavigate } from "react-router";
import { useMutation } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { authApi } from "~/features/auth/api/auth-api";
import { useAuthStore } from "~/store/useAuthStore";
import { ProtectedRoute } from "~/components/ProtectedRoute";
import { Button, Card, CardHeader, CardTitle, CardContent, CardFooter } from "~/components/ui";

/**
 * Dashboard Page Component
 *
 * Protected page that displays user information and provides logout functionality.
 * Only accessible to authenticated users.
 */
function DashboardContent() {
  const navigate = useNavigate();
  const { user, logout: storeLogout } = useAuthStore();

  // Logout mutation
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

  // Format role for display
  const formatRole = (role: string) => {
    return role.charAt(0).toUpperCase() + role.slice(1).replace(/_/g, " ");
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950">
      {/* Header */}
      <header className="bg-white dark:bg-gray-900 shadow-sm border-b border-gray-200 dark:border-gray-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
          <h1 className="text-xl sm:text-2xl font-bold text-primary-600 dark:text-primary-400">
            MediConnect
          </h1>
          <Button
            variant="outline"
            size="sm"
            onClick={handleLogout}
            isLoading={logoutMutation.isPending}
            loadingText="Logging out"
          >
            Logout
          </Button>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h2 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Welcome back, {user?.first_name}!
          </h2>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Manage your healthcare from your personal dashboard.
          </p>
        </div>

        {/* User Info Card */}
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle as="h3">Your Profile</CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="space-y-3">
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Full Name
                  </dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                    {user?.first_name} {user?.last_name}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Email</dt>
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">{user?.email}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Role</dt>
                  <dd className="mt-1">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-100 text-primary-800 dark:bg-primary-900 dark:text-primary-200">
                      {user?.role ? formatRole(user.role) : "User"}
                    </span>
                  </dd>
                </div>
                {user?.phone && (
                  <div>
                    <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Phone</dt>
                    <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">
                      {user.phone}
                    </dd>
                  </div>
                )}
              </dl>
            </CardContent>
            <CardFooter>
              <Button variant="ghost" size="sm" disabled>
                Edit Profile (Coming Soon)
              </Button>
            </CardFooter>
          </Card>

          {/* Quick Actions Card */}
          <Card>
            <CardHeader>
              <CardTitle as="h3">Quick Actions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <Button variant="secondary" fullWidth disabled>
                  Book Appointment
                </Button>
                <Button variant="outline" fullWidth disabled>
                  View Medical Records
                </Button>
                <Button variant="outline" fullWidth disabled>
                  Message Doctor
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Upcoming Appointments Card */}
          <Card>
            <CardHeader>
              <CardTitle as="h3">Upcoming Appointments</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-center py-6">
                <svg
                  className="mx-auto h-12 w-12 text-gray-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={1.5}
                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
                <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
                  No upcoming appointments
                </p>
                <p className="text-xs text-gray-400 dark:text-gray-500">
                  Book your first appointment to get started
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </main>
    </div>
  );
}

/**
 * Dashboard Page with Protection
 * Wrapped in ProtectedRoute to ensure authentication
 */
export default function DashboardPage() {
  return (
    <ProtectedRoute>
      <DashboardContent />
    </ProtectedRoute>
  );
}
