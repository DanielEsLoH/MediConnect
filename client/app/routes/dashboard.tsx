import { Link } from "react-router";

import { useAuthStore } from "~/store/useAuthStore";
import { Button, Card, CardHeader, CardTitle, CardContent, CardFooter } from "~/components/ui";

/**
 * Dashboard Page Component
 *
 * Main dashboard page that displays user information and quick actions.
 * Authentication is handled by the MainLayout wrapper.
 */
export default function DashboardPage() {
  const user = useAuthStore((state) => state.user);

  // Format role for display
  const formatRole = (role: string) => {
    return role.charAt(0).toUpperCase() + role.slice(1).replace(/_/g, " ");
  };

  return (
    <>
      {/* Welcome Section */}
      <div className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Welcome back, {user?.first_name}!
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Manage your healthcare from your personal dashboard.
        </p>
      </div>

      {/* Dashboard Cards Grid */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {/* User Profile Card */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Your Profile</CardTitle>
          </CardHeader>
          <CardContent>
            <dl className="space-y-3">
              <div>
                <dt className="text-sm font-medium text-gray-500 dark:text-gray-400">Full Name</dt>
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
                  <dd className="mt-1 text-base text-gray-900 dark:text-gray-100">{user.phone}</dd>
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
            <CardTitle as="h2">Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <Link
                to="/appointments"
                className="flex items-center justify-center w-full min-h-11 px-4 py-2.5 text-base font-medium text-white bg-secondary-600 rounded-lg hover:bg-secondary-700 active:bg-secondary-800 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-secondary-500 sm:min-h-10 sm:py-2"
              >
                Book Appointment
              </Link>
              <Link
                to="/doctors"
                className="flex items-center justify-center w-full min-h-11 px-4 py-2.5 text-base font-medium text-primary-600 bg-transparent border-2 border-primary-600 rounded-lg hover:bg-primary-50 active:bg-primary-100 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-primary-500 sm:min-h-10 sm:py-2"
              >
                Find a Doctor
              </Link>
              <Button variant="outline" fullWidth disabled>
                View Medical Records
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Upcoming Appointments Card */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Upcoming Appointments</CardTitle>
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
          <CardFooter className="justify-center">
            <Link
              to="/appointments"
              className="inline-flex items-center justify-center gap-2 min-h-11 px-3 py-2 text-sm font-medium text-gray-700 bg-transparent rounded-lg hover:bg-gray-100 active:bg-gray-200 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-gray-500 dark:text-gray-300 dark:hover:bg-gray-800 dark:active:bg-gray-700 sm:min-h-9 sm:py-1.5"
            >
              View All Appointments
            </Link>
          </CardFooter>
        </Card>
      </div>
    </>
  );
}
