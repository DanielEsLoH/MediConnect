import type { MedicalHistory } from "~/types/auth";
import { Card, CardHeader, CardTitle, CardContent } from "~/components/ui";
import { cn } from "~/lib/utils";

interface MedicalHistoryCardProps {
  /** Medical history data to display */
  medicalHistory?: MedicalHistory;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Badge component for displaying list items
 */
function ItemBadge({ children }: { children: React.ReactNode }) {
  return (
    <span
      className={cn(
        "inline-flex items-center",
        "px-2.5 py-1 rounded-full",
        "text-xs sm:text-sm font-medium",
        "bg-gray-100 text-gray-700",
        "dark:bg-gray-800 dark:text-gray-300"
      )}
    >
      {children}
    </span>
  );
}

/**
 * Empty state for when no data is available
 */
function EmptyState({ message }: { message: string }) {
  return (
    <p className="text-sm text-gray-400 dark:text-gray-500 italic">
      {message}
    </p>
  );
}

/**
 * Section component for organizing medical data
 */
interface SectionProps {
  icon: React.ReactNode;
  title: string;
  children: React.ReactNode;
}

function Section({ icon, title, children }: SectionProps) {
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <span className="text-gray-400 dark:text-gray-500">{icon}</span>
        <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">
          {title}
        </h4>
      </div>
      <div className="pl-7">{children}</div>
    </div>
  );
}

/**
 * MedicalHistoryCard Component
 *
 * Displays read-only medical history information including:
 * - Blood type
 * - Allergies
 * - Chronic conditions
 * - Current medications
 *
 * Features:
 * - Clean, organized layout with icons
 * - Badge-style display for list items
 * - Empty states when no data is available
 * - Accessible with proper semantic structure
 * - Note indicating read-only status
 *
 * @example
 * <MedicalHistoryCard medicalHistory={user.medical_history} />
 */
export function MedicalHistoryCard({ medicalHistory, className }: MedicalHistoryCardProps) {
  const bloodType = medicalHistory?.blood_type;
  const allergies = medicalHistory?.allergies || [];
  const chronicConditions = medicalHistory?.chronic_conditions || [];
  const currentMedications = medicalHistory?.current_medications || [];

  const hasAnyData = bloodType || allergies.length > 0 || chronicConditions.length > 0 || currentMedications.length > 0;

  return (
    <Card padding="lg" className={className}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle as="h3">Medical History</CardTitle>
          {/* Medical cross icon */}
          <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-error-100 dark:bg-error-900/30">
            <svg
              className="w-4 h-4 text-error-600 dark:text-error-400"
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
        </div>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Your medical information for healthcare providers.
        </p>
      </CardHeader>

      <CardContent>
        {!hasAnyData ? (
          <div className="text-center py-6">
            <div className="mx-auto w-12 h-12 flex items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 mb-3">
              <svg
                className="w-6 h-6 text-gray-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={1.5}
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                />
              </svg>
            </div>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              No medical history on file.
            </p>
            <p className="mt-1 text-xs text-gray-400 dark:text-gray-500">
              Contact your healthcare provider to add your medical information.
            </p>
          </div>
        ) : (
          <div className="space-y-5">
            {/* Blood Type */}
            <Section
              icon={
                <svg
                  className="w-4 h-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"
                  />
                </svg>
              }
              title="Blood Type"
            >
              {bloodType ? (
                <span
                  className={cn(
                    "inline-flex items-center",
                    "px-3 py-1.5 rounded-lg",
                    "text-sm font-semibold",
                    "bg-error-100 text-error-700",
                    "dark:bg-error-900/30 dark:text-error-300"
                  )}
                >
                  {bloodType}
                </span>
              ) : (
                <EmptyState message="Not recorded" />
              )}
            </Section>

            {/* Allergies */}
            <Section
              icon={
                <svg
                  className="w-4 h-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
              }
              title="Allergies"
            >
              {allergies.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {allergies.map((allergy, index) => (
                    <ItemBadge key={index}>{allergy}</ItemBadge>
                  ))}
                </div>
              ) : (
                <EmptyState message="No known allergies" />
              )}
            </Section>

            {/* Chronic Conditions */}
            <Section
              icon={
                <svg
                  className="w-4 h-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
                  />
                </svg>
              }
              title="Chronic Conditions"
            >
              {chronicConditions.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {chronicConditions.map((condition, index) => (
                    <ItemBadge key={index}>{condition}</ItemBadge>
                  ))}
                </div>
              ) : (
                <EmptyState message="No chronic conditions recorded" />
              )}
            </Section>

            {/* Current Medications */}
            <Section
              icon={
                <svg
                  className="w-4 h-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"
                  />
                </svg>
              }
              title="Current Medications"
            >
              {currentMedications.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {currentMedications.map((medication, index) => (
                    <ItemBadge key={index}>{medication}</ItemBadge>
                  ))}
                </div>
              ) : (
                <EmptyState message="No current medications" />
              )}
            </Section>
          </div>
        )}

        {/* Read-only note */}
        <div className="mt-6 pt-4 border-t border-gray-200 dark:border-gray-700">
          <p className="text-xs text-gray-400 dark:text-gray-500 flex items-center gap-1.5">
            <svg
              className="w-3.5 h-3.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            Medical history can only be updated by healthcare providers.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
