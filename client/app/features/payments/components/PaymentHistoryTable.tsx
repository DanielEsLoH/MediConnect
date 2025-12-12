import { cn } from "~/lib/utils";
import type { Payment, PaymentStatus } from "../types";

export interface PaymentHistoryTableProps {
  /** List of payments to display */
  payments: Payment[];
  /** Callback when "View Details" is clicked (receives payment id) */
  onViewDetails?: (id: number) => void;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Format amount from cents to display format.
 * @param amount - Amount in cents
 * @param currency - Currency code (e.g., "USD")
 * @returns Formatted currency string (e.g., "$50.00")
 */
function formatAmount(amount: number, currency: string): string {
  const formatter = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency.toUpperCase(),
    minimumFractionDigits: 2,
  });
  // Convert cents to dollars
  return formatter.format(amount / 100);
}

/**
 * Format a date string for display.
 * @param dateString - ISO 8601 date string
 * @returns Formatted date (e.g., "Dec 15, 2025")
 */
function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

/**
 * Get status badge configuration based on payment status.
 */
function getStatusBadgeConfig(status: PaymentStatus): {
  label: string;
  className: string;
} {
  switch (status) {
    case "completed":
      return {
        label: "Completed",
        className:
          "bg-success-100 text-success-800 dark:bg-success-900/30 dark:text-success-400",
      };
    case "pending":
      return {
        label: "Pending",
        className:
          "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400",
      };
    case "processing":
      return {
        label: "Processing",
        className:
          "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400",
      };
    case "failed":
      return {
        label: "Failed",
        className:
          "bg-error-100 text-error-800 dark:bg-error-900/30 dark:text-error-400",
      };
    case "refunded":
      return {
        label: "Refunded",
        className: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400",
      };
    default:
      return {
        label: status,
        className: "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400",
      };
  }
}

/**
 * Get doctor name from payment appointment data.
 */
function getDoctorName(payment: Payment): string {
  if (payment.appointment?.doctor?.full_name) {
    return payment.appointment.doctor.full_name;
  }
  if (payment.appointment_id) {
    return `Appointment #${payment.appointment_id}`;
  }
  return payment.description || "Payment";
}

/**
 * Empty state component for when there are no payments.
 */
function EmptyState() {
  return (
    <div className="text-center py-12 sm:py-16">
      {/* Credit card icon */}
      <div className="mx-auto w-16 h-16 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 mb-4">
        <svg
          className="w-8 h-8 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"
          />
        </svg>
      </div>
      <h3 className="text-lg font-medium text-gray-900 dark:text-gray-100">
        No payment history yet
      </h3>
      <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-sm mx-auto">
        Your payment transactions will appear here once you make your first
        payment.
      </p>
    </div>
  );
}

/**
 * Mobile card view for a single payment.
 */
interface PaymentCardProps {
  payment: Payment;
  onViewDetails?: (id: number) => void;
}

function PaymentCard({ payment, onViewDetails }: PaymentCardProps) {
  const statusBadge = getStatusBadgeConfig(payment.status);
  const doctorName = getDoctorName(payment);

  return (
    <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl p-4 shadow-sm">
      {/* Header: Doctor name and status */}
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="min-w-0 flex-1">
          <h4 className="font-medium text-gray-900 dark:text-gray-100 truncate">
            {doctorName}
          </h4>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
            {formatDate(payment.paid_at || payment.created_at)}
          </p>
        </div>
        <span
          className={cn(
            "shrink-0 inline-flex items-center px-2.5 py-0.5 rounded-full",
            "text-xs font-medium",
            statusBadge.className
          )}
        >
          {statusBadge.label}
        </span>
      </div>

      {/* Amount and action */}
      <div className="flex items-center justify-between">
        <span className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          {formatAmount(payment.amount, payment.currency)}
        </span>
        {onViewDetails && (
          <button
            type="button"
            onClick={() => onViewDetails(payment.id)}
            className="text-sm font-medium text-primary-600 hover:text-primary-700 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
            aria-label={`View details for payment to ${doctorName}`}
          >
            View Details
          </button>
        )}
      </div>
    </div>
  );
}

/**
 * PaymentHistoryTable component displays payment history in a responsive format.
 * Shows a table on desktop and stacked cards on mobile.
 *
 * @example
 * <PaymentHistoryTable
 *   payments={payments}
 *   onViewDetails={(id) => console.log('View payment', id)}
 * />
 */
export function PaymentHistoryTable({
  payments,
  onViewDetails,
  className,
}: PaymentHistoryTableProps) {
  if (payments.length === 0) {
    return <EmptyState />;
  }

  return (
    <div className={className}>
      {/* Desktop Table View */}
      <div className="hidden md:block overflow-hidden rounded-xl border border-gray-200 dark:border-gray-800">
        <table className="w-full">
          <thead className="bg-gray-50 dark:bg-gray-800/50">
            <tr>
              <th
                scope="col"
                className="px-4 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Date
              </th>
              <th
                scope="col"
                className="px-4 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Description
              </th>
              <th
                scope="col"
                className="px-4 py-3 text-right text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Amount
              </th>
              <th
                scope="col"
                className="px-4 py-3 text-center text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider"
              >
                Status
              </th>
              <th scope="col" className="relative px-4 py-3">
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 dark:divide-gray-800 bg-white dark:bg-gray-900">
            {payments.map((payment) => {
              const statusBadge = getStatusBadgeConfig(payment.status);
              const doctorName = getDoctorName(payment);

              return (
                <tr
                  key={payment.id}
                  className="hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors"
                >
                  <td className="px-4 py-4 whitespace-nowrap">
                    <span className="text-sm text-gray-700 dark:text-gray-300">
                      {formatDate(payment.paid_at || payment.created_at)}
                    </span>
                  </td>
                  <td className="px-4 py-4">
                    <div className="flex flex-col">
                      <span className="text-sm font-medium text-gray-900 dark:text-gray-100">
                        {doctorName}
                      </span>
                      {payment.appointment?.doctor?.specialty && (
                        <span className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
                          {payment.appointment.doctor.specialty}
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap text-right">
                    <span className="text-sm font-semibold text-gray-900 dark:text-gray-100">
                      {formatAmount(payment.amount, payment.currency)}
                    </span>
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap text-center">
                    <span
                      className={cn(
                        "inline-flex items-center px-2.5 py-0.5 rounded-full",
                        "text-xs font-medium",
                        statusBadge.className
                      )}
                    >
                      {statusBadge.label}
                    </span>
                  </td>
                  <td className="px-4 py-4 whitespace-nowrap text-right">
                    {onViewDetails && (
                      <button
                        type="button"
                        onClick={() => onViewDetails(payment.id)}
                        className="text-sm font-medium text-primary-600 hover:text-primary-700 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                        aria-label={`View details for payment to ${doctorName}`}
                      >
                        View Details
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Mobile Card View */}
      <div className="md:hidden space-y-3">
        {payments.map((payment) => (
          <PaymentCard
            key={payment.id}
            payment={payment}
            onViewDetails={onViewDetails}
          />
        ))}
      </div>
    </div>
  );
}
