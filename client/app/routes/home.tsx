import { Link, useNavigate } from "react-router";
import { useQuery } from "@tanstack/react-query";

import { useAuthStore } from "~/store/useAuthStore";
import { useNotificationStore } from "~/features/notifications/store/useNotificationStore";
import { Button, Card, CardHeader, CardTitle, CardContent, Spinner } from "~/components/ui";
import { cn } from "~/lib/utils";
import { appointmentsApi, type Appointment } from "~/features/appointments";
import { notificationsApi, type Notification } from "~/features/notifications";

import type { Route } from "./+types/home";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "MediConnect - Medical Appointment Platform" },
    {
      name: "description",
      content: "MediConnect - Your trusted medical appointment management platform",
    },
  ];
}

/**
 * Query keys for home page data.
 */
const homeKeys = {
  appointments: ["home", "appointments"] as const,
  notifications: ["home", "notifications"] as const,
};

/**
 * Format a date string for display.
 */
function formatDate(dateString: string): string {
  const date = new Date(dateString + "T00:00:00");
  return date.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

/**
 * Format time from HH:mm to display format.
 */
function formatTime(time: string): string {
  const [hours, minutes] = time.split(":").map(Number);
  const period = hours >= 12 ? "PM" : "AM";
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes.toString().padStart(2, "0")} ${period}`;
}

/**
 * Get relative time for notifications.
 */
function getRelativeTime(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return "Just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

/**
 * Get upcoming appointments (future, not cancelled/completed).
 */
function getUpcomingAppointments(appointments: Appointment[]): Appointment[] {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return appointments
    .filter((apt) => {
      const aptDate = new Date(apt.appointment_date + "T00:00:00");
      return (
        aptDate >= today &&
        apt.status !== "cancelled" &&
        apt.status !== "completed" &&
        apt.status !== "no_show"
      );
    })
    .sort((a, b) => {
      const dateA = new Date(`${a.appointment_date}T${a.start_time}`);
      const dateB = new Date(`${b.appointment_date}T${b.start_time}`);
      return dateA.getTime() - dateB.getTime();
    })
    .slice(0, 3);
}

/**
 * Get notification icon based on type.
 */
function getNotificationIcon(type: string): React.ReactNode {
  switch (type) {
    case "appointment_created":
    case "appointment_confirmed":
    case "appointment_reminder":
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
          />
        </svg>
      );
    case "appointment_cancelled":
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      );
    case "payment_completed":
    case "payment_failed":
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
          />
        </svg>
      );
    case "review_requested":
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
          />
        </svg>
      );
    default:
      return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
          />
        </svg>
      );
  }
}

/**
 * Quick Action Button Component.
 */
interface QuickActionProps {
  icon: React.ReactNode;
  label: string;
  to: string;
  variant?: "primary" | "secondary";
}

function QuickAction({ icon, label, to, variant = "secondary" }: QuickActionProps) {
  return (
    <Link
      to={to}
      className={cn(
        "flex flex-col items-center gap-2 p-4 rounded-xl transition-all duration-200",
        "hover:scale-105 active:scale-95",
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2",
        variant === "primary"
          ? "bg-primary-600 text-white hover:bg-primary-700 focus-visible:ring-primary-500"
          : "bg-white border border-gray-200 text-gray-700 hover:border-primary-300 hover:bg-primary-50 focus-visible:ring-primary-500 dark:bg-gray-800 dark:border-gray-700 dark:text-gray-300 dark:hover:border-primary-600 dark:hover:bg-primary-900/20"
      )}
    >
      <div className={cn(
        "w-12 h-12 rounded-full flex items-center justify-center",
        variant === "primary"
          ? "bg-white/20"
          : "bg-primary-100 text-primary-600 dark:bg-primary-900/40 dark:text-primary-400"
      )}>
        {icon}
      </div>
      <span className="text-sm font-medium text-center">{label}</span>
    </Link>
  );
}

/**
 * Appointment Mini Card for upcoming appointments widget.
 */
interface AppointmentMiniCardProps {
  appointment: Appointment;
}

function AppointmentMiniCard({ appointment }: AppointmentMiniCardProps) {
  const doctorName = appointment.doctor?.full_name ?? `Doctor #${appointment.doctor_id}`;
  const specialty = appointment.doctor?.specialty ?? "Medical Professional";

  return (
    <Link
      to={`/appointments/${appointment.id}`}
      className={cn(
        "block p-4 rounded-lg border transition-all duration-200",
        "bg-white border-gray-200 hover:border-primary-300 hover:shadow-sm",
        "dark:bg-gray-800 dark:border-gray-700 dark:hover:border-primary-600",
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2"
      )}
    >
      <div className="flex items-center gap-3">
        {/* Date Badge */}
        <div className="shrink-0 w-14 h-14 rounded-lg bg-primary-100 dark:bg-primary-900/40 flex flex-col items-center justify-center">
          <span className="text-xs font-medium text-primary-600 dark:text-primary-400 uppercase">
            {new Date(appointment.appointment_date + "T00:00:00").toLocaleDateString("en-US", { weekday: "short" })}
          </span>
          <span className="text-lg font-bold text-primary-700 dark:text-primary-300">
            {new Date(appointment.appointment_date + "T00:00:00").getDate()}
          </span>
        </div>

        {/* Appointment Info */}
        <div className="flex-1 min-w-0">
          <p className="font-medium text-gray-900 dark:text-gray-100 truncate">{doctorName}</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">{specialty}</p>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            {formatTime(appointment.start_time)}
            {appointment.consultation_type === "video" && (
              <span className="ml-2 inline-flex items-center text-primary-600 dark:text-primary-400">
                <svg className="w-3.5 h-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                  />
                </svg>
                Video
              </span>
            )}
          </p>
        </div>

        {/* Arrow Icon */}
        <svg className="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
        </svg>
      </div>
    </Link>
  );
}

/**
 * Activity Item Component.
 */
interface ActivityItemProps {
  notification: Notification;
}

function ActivityItem({ notification }: ActivityItemProps) {
  return (
    <div
      className={cn(
        "flex items-start gap-3 p-3 rounded-lg transition-colors",
        notification.read_at
          ? "bg-transparent"
          : "bg-primary-50 dark:bg-primary-900/20"
      )}
    >
      <div
        className={cn(
          "shrink-0 w-10 h-10 rounded-full flex items-center justify-center",
          notification.read_at
            ? "bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400"
            : "bg-primary-100 text-primary-600 dark:bg-primary-900/40 dark:text-primary-400"
        )}
      >
        {getNotificationIcon(notification.notification_type)}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900 dark:text-gray-100">{notification.title}</p>
        <p className="text-sm text-gray-500 dark:text-gray-400 line-clamp-2">{notification.message}</p>
        <p className="mt-1 text-xs text-gray-400 dark:text-gray-500">
          {getRelativeTime(notification.created_at)}
        </p>
      </div>
    </div>
  );
}

/**
 * Health Tip Card Component.
 */
const healthTips = [
  {
    title: "Stay Hydrated",
    description: "Drink at least 8 glasses of water daily to maintain optimal health and energy levels.",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
      </svg>
    ),
  },
  {
    title: "Regular Check-ups",
    description: "Schedule annual health screenings to catch potential issues early and maintain your wellbeing.",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
  },
  {
    title: "Mental Wellness",
    description: "Take time for self-care and don't hesitate to seek professional support when needed.",
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
      </svg>
    ),
  },
];

/**
 * Home/Landing Page Component
 *
 * Landing page for authenticated users with:
 * - Hero section with welcome message and quick stats
 * - Quick actions (book appointment, find doctor, etc.)
 * - Upcoming appointments widget
 * - Recent activity feed
 * - Health tips section
 */
export default function HomePage() {
  const navigate = useNavigate();
  const { user, isAuthenticated } = useAuthStore();
  const { unreadCount } = useNotificationStore();

  // Fetch appointments
  const {
    data: appointments,
    isLoading: isLoadingAppointments,
  } = useQuery({
    queryKey: homeKeys.appointments,
    queryFn: appointmentsApi.getAppointments,
    enabled: isAuthenticated,
    staleTime: 1000 * 60 * 2,
  });

  // Fetch notifications
  const {
    data: notificationsData,
    isLoading: isLoadingNotifications,
  } = useQuery({
    queryKey: homeKeys.notifications,
    queryFn: () => notificationsApi.getNotifications(1, 5),
    enabled: isAuthenticated,
    retry: 1,
    staleTime: 1000 * 60,
  });

  // If not authenticated, show public landing page
  if (!isAuthenticated || !user) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-primary-50 via-white to-secondary-50 dark:from-gray-900 dark:via-gray-900 dark:to-gray-800">
        {/* Public Hero Section */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-16 pb-24">
          <div className="text-center">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 dark:text-gray-100">
              Welcome to{" "}
              <span className="text-primary-600 dark:text-primary-400">MediConnect</span>
            </h1>
            <p className="mt-6 text-lg sm:text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
              Your trusted platform for managing medical appointments. Connect with healthcare professionals anytime, anywhere.
            </p>
            <div className="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <Link to="/register">
                <Button variant="primary" size="lg">
                  Get Started
                </Button>
              </Link>
              <Link to="/login">
                <Button variant="outline" size="lg">
                  Sign In
                </Button>
              </Link>
            </div>
          </div>

          {/* Feature Cards */}
          <div className="mt-20 grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
            <Card hover className="text-center">
              <CardContent className="py-8">
                <div className="mx-auto w-14 h-14 rounded-full bg-primary-100 dark:bg-primary-900/40 flex items-center justify-center mb-4">
                  <svg className="w-7 h-7 text-primary-600 dark:text-primary-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Easy Booking</h3>
                <p className="mt-2 text-gray-600 dark:text-gray-400">
                  Schedule appointments with just a few clicks. No phone calls needed.
                </p>
              </CardContent>
            </Card>

            <Card hover className="text-center">
              <CardContent className="py-8">
                <div className="mx-auto w-14 h-14 rounded-full bg-secondary-100 dark:bg-secondary-900/40 flex items-center justify-center mb-4">
                  <svg className="w-7 h-7 text-secondary-600 dark:text-secondary-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Video Consultations</h3>
                <p className="mt-2 text-gray-600 dark:text-gray-400">
                  Meet with doctors from the comfort of your home via secure video calls.
                </p>
              </CardContent>
            </Card>

            <Card hover className="text-center sm:col-span-2 lg:col-span-1">
              <CardContent className="py-8">
                <div className="mx-auto w-14 h-14 rounded-full bg-success-100 dark:bg-success-900/40 flex items-center justify-center mb-4">
                  <svg className="w-7 h-7 text-success-600 dark:text-success-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Secure & Private</h3>
                <p className="mt-2 text-gray-600 dark:text-gray-400">
                  Your health data is protected with enterprise-grade security.
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    );
  }

  // Authenticated user home page
  const upcomingAppointments = appointments ? getUpcomingAppointments(appointments) : [];
  const recentNotifications = notificationsData?.data?.slice(0, 4) ?? [];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Hero Section */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Welcome back, {user.first_name}!
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Here's what's happening with your healthcare today.
          </p>

          {/* Quick Stats */}
          <div className="mt-6 grid grid-cols-2 sm:grid-cols-4 gap-4">
            <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border border-gray-200 dark:border-gray-700">
              <p className="text-2xl font-bold text-primary-600 dark:text-primary-400">
                {upcomingAppointments.length}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Upcoming</p>
            </div>
            <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border border-gray-200 dark:border-gray-700">
              <p className="text-2xl font-bold text-secondary-600 dark:text-secondary-400">
                {unreadCount}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Messages</p>
            </div>
            <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border border-gray-200 dark:border-gray-700">
              <p className="text-2xl font-bold text-success-600 dark:text-success-400">
                {appointments?.filter((a) => a.status === "completed").length ?? 0}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Completed</p>
            </div>
            <div className="bg-white dark:bg-gray-800 rounded-xl p-4 border border-gray-200 dark:border-gray-700">
              <p className="text-2xl font-bold text-gray-600 dark:text-gray-400">
                {appointments?.length ?? 0}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400">Total Visits</p>
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <section className="mb-8" aria-labelledby="quick-actions-heading">
          <h2 id="quick-actions-heading" className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
            Quick Actions
          </h2>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <QuickAction
              icon={
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
              }
              label="Book Appointment"
              to="/doctors"
              variant="primary"
            />
            <QuickAction
              icon={
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              }
              label="Find Doctor"
              to="/doctors"
            />
            <QuickAction
              icon={
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
              }
              label="View Schedule"
              to="/appointments"
            />
            <QuickAction
              icon={
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              }
              label="Join Video Call"
              to="/appointments"
            />
          </div>
        </section>

        {/* Main Content Grid */}
        <div className="grid gap-8 lg:grid-cols-3">
          {/* Upcoming Appointments */}
          <section className="lg:col-span-2" aria-labelledby="appointments-heading">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle as="h2" className="text-base sm:text-lg">
                    Upcoming Appointments
                  </CardTitle>
                  <Link
                    to="/appointments"
                    className="text-sm font-medium text-primary-600 hover:text-primary-700 dark:text-primary-400 dark:hover:text-primary-300"
                  >
                    View All
                  </Link>
                </div>
              </CardHeader>
              <CardContent>
                {isLoadingAppointments ? (
                  <div className="flex items-center justify-center py-8">
                    <Spinner size="md" label="Loading appointments..." />
                  </div>
                ) : upcomingAppointments.length > 0 ? (
                  <div className="space-y-3">
                    {upcomingAppointments.map((appointment) => (
                      <AppointmentMiniCard key={appointment.id} appointment={appointment} />
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-8">
                    <div className="mx-auto w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-3">
                      <svg className="w-6 h-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    </div>
                    <p className="text-sm text-gray-500 dark:text-gray-400">No upcoming appointments</p>
                    <Link to="/doctors">
                      <Button variant="outline" size="sm" className="mt-4">
                        Book Now
                      </Button>
                    </Link>
                  </div>
                )}
              </CardContent>
            </Card>
          </section>

          {/* Recent Activity */}
          <section aria-labelledby="activity-heading">
            <Card>
              <CardHeader>
                <CardTitle as="h2" className="text-base sm:text-lg">
                  Recent Activity
                </CardTitle>
              </CardHeader>
              <CardContent>
                {isLoadingNotifications ? (
                  <div className="flex items-center justify-center py-8">
                    <Spinner size="sm" label="Loading..." />
                  </div>
                ) : recentNotifications.length > 0 ? (
                  <div className="space-y-2">
                    {recentNotifications.map((notification) => (
                      <ActivityItem key={notification.id} notification={notification} />
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-8">
                    <div className="mx-auto w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-3">
                      <svg className="w-6 h-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                      </svg>
                    </div>
                    <p className="text-sm text-gray-500 dark:text-gray-400">No recent activity</p>
                  </div>
                )}
              </CardContent>
            </Card>
          </section>
        </div>

        {/* Health Tips Section */}
        <section className="mt-8" aria-labelledby="tips-heading">
          <h2 id="tips-heading" className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
            Health Tips
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {healthTips.map((tip, index) => (
              <Card key={index} hover>
                <CardContent className="flex items-start gap-4">
                  <div className="shrink-0 w-10 h-10 rounded-lg bg-success-100 dark:bg-success-900/40 flex items-center justify-center text-success-600 dark:text-success-400">
                    {tip.icon}
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900 dark:text-gray-100">{tip.title}</h3>
                    <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{tip.description}</p>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}