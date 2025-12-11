import { Link } from "react-router";

import { Card, CardHeader, CardTitle, CardContent } from "~/components/ui";

/**
 * Appointments Page Component
 *
 * Placeholder page for managing appointments.
 * Will be implemented with full functionality in future phases.
 */
export default function AppointmentsPage() {
  return (
    <>
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Your Appointments
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          View, schedule, and manage your medical appointments.
        </p>
      </div>

      {/* Appointments Grid */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Upcoming Appointments Card */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Upcoming Appointments</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-center py-8">
              {/* Calendar icon */}
              <svg
                className="mx-auto h-14 w-14 text-gray-400"
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
              <h3 className="mt-4 text-base font-medium text-gray-900 dark:text-gray-100">
                No Upcoming Appointments
              </h3>
              <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
                You don't have any scheduled appointments yet.
              </p>
              <Link
                to="/doctors"
                className="mt-4 inline-flex items-center justify-center min-h-11 px-4 py-2.5 text-sm font-medium text-white bg-primary-600 rounded-lg hover:bg-primary-700 active:bg-primary-800 transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-primary-500 sm:min-h-10 sm:py-2"
              >
                Find a Doctor
              </Link>
            </div>
          </CardContent>
        </Card>

        {/* Past Appointments Card */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Past Appointments</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-center py-8">
              {/* Clock icon */}
              <svg
                className="mx-auto h-14 w-14 text-gray-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={1.5}
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <h3 className="mt-4 text-base font-medium text-gray-900 dark:text-gray-100">
                No Past Appointments
              </h3>
              <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
                Your appointment history will appear here.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="mt-8">
        <Card>
          <CardHeader>
            <CardTitle as="h2">Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div className="p-4 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-primary-300 dark:hover:border-primary-700 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="shrink-0 w-10 h-10 flex items-center justify-center rounded-lg bg-primary-100 dark:bg-primary-900">
                    <svg
                      className="w-5 h-5 text-primary-600 dark:text-primary-400"
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
                  <div>
                    <h4 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                      Schedule New
                    </h4>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      Book a new appointment
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-4 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-secondary-300 dark:hover:border-secondary-700 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="shrink-0 w-10 h-10 flex items-center justify-center rounded-lg bg-secondary-100 dark:bg-secondary-900">
                    <svg
                      className="w-5 h-5 text-secondary-600 dark:text-secondary-400"
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
                  </div>
                  <div>
                    <h4 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                      View Calendar
                    </h4>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      See all your appointments
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-4 rounded-lg border border-gray-200 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-500 transition-colors">
                <div className="flex items-center gap-3">
                  <div className="shrink-0 w-10 h-10 flex items-center justify-center rounded-lg bg-gray-100 dark:bg-gray-800">
                    <svg
                      className="w-5 h-5 text-gray-600 dark:text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                      />
                    </svg>
                  </div>
                  <div>
                    <h4 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                      Medical Records
                    </h4>
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      Access your health records
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </>
  );
}
