import { cn } from "~/lib/utils";
import { StarRating } from "./StarRating";
import type { ReviewStats as ReviewStatsType, RatingDistribution } from "~/features/reviews/types";

/**
 * Props for the ReviewStats component.
 */
export interface ReviewStatsProps {
  /** Review statistics data */
  stats: ReviewStatsType;
  /** Whether stats are loading */
  isLoading?: boolean;
  /** Additional CSS classes */
  className?: string;
  /** Whether to show a compact version */
  compact?: boolean;
}

/**
 * Rating levels for the distribution bars.
 */
const RATING_LEVELS = [5, 4, 3, 2, 1] as const;

/**
 * Loading skeleton for the stats component.
 */
function StatsSkeleton({ compact }: { compact?: boolean }) {
  if (compact) {
    return (
      <div className="flex items-center gap-2 animate-pulse" aria-hidden="true">
        <div className="w-8 h-6 bg-gray-200 dark:bg-gray-700 rounded" />
        <div className="flex gap-0.5">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="w-4 h-4 bg-gray-200 dark:bg-gray-700 rounded" />
          ))}
        </div>
        <div className="w-16 h-4 bg-gray-200 dark:bg-gray-700 rounded" />
      </div>
    );
  }

  return (
    <div className="animate-pulse" aria-hidden="true">
      <div className="flex flex-col sm:flex-row gap-6">
        {/* Average rating skeleton */}
        <div className="flex flex-col items-center sm:items-start gap-2">
          <div className="w-16 h-12 bg-gray-200 dark:bg-gray-700 rounded" />
          <div className="flex gap-1">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="w-5 h-5 bg-gray-200 dark:bg-gray-700 rounded" />
            ))}
          </div>
          <div className="w-24 h-4 bg-gray-200 dark:bg-gray-700 rounded" />
        </div>

        {/* Distribution bars skeleton */}
        <div className="flex-1 space-y-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="flex items-center gap-2">
              <div className="w-8 h-4 bg-gray-200 dark:bg-gray-700 rounded" />
              <div className="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-full" />
              <div className="w-8 h-4 bg-gray-200 dark:bg-gray-700 rounded" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/**
 * Calculate the percentage for a rating level.
 */
function calculatePercentage(count: number, total: number): number {
  if (total === 0) return 0;
  return Math.round((count / total) * 100);
}

/**
 * Format the total reviews count for display.
 */
function formatReviewCount(count: number): string {
  if (count === 0) return "No reviews";
  if (count === 1) return "1 review";
  if (count >= 1000) {
    return `${(count / 1000).toFixed(1)}k reviews`;
  }
  return `${count} reviews`;
}

/**
 * Rating distribution bar component.
 */
function RatingBar({
  level,
  count,
  percentage,
}: {
  level: number;
  count: number;
  percentage: number;
}) {
  return (
    <div className="flex items-center gap-2">
      {/* Star level label */}
      <div className="flex items-center justify-end w-8 gap-0.5 text-sm text-gray-600 dark:text-gray-400">
        <span>{level}</span>
        <svg
          className="w-3 h-3 text-yellow-400"
          viewBox="0 0 24 24"
          fill="currentColor"
          aria-hidden="true"
        >
          <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z" />
        </svg>
      </div>

      {/* Progress bar */}
      <div
        className="flex-1 h-2 rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden"
        role="progressbar"
        aria-valuenow={percentage}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`${level} star reviews: ${percentage}%`}
      >
        <div
          className={cn(
            "h-full rounded-full transition-all duration-500 ease-out",
            level >= 4 && "bg-green-500",
            level === 3 && "bg-yellow-500",
            level <= 2 && "bg-red-500"
          )}
          style={{ width: `${percentage}%` }}
        />
      </div>

      {/* Count/Percentage */}
      <div className="w-12 text-right text-sm text-gray-500 dark:text-gray-400">
        {count > 0 ? `${percentage}%` : "-"}
      </div>
    </div>
  );
}

/**
 * ReviewStats Component
 *
 * Displays aggregated review statistics including average rating,
 * total count, and rating distribution breakdown.
 *
 * Features:
 * - Large average rating display with stars
 * - Total review count
 * - Visual rating distribution bars (5-1 stars)
 * - Color-coded bars (green for high, yellow for medium, red for low)
 * - Loading skeleton state
 * - Compact mode for smaller displays
 * - Responsive layout
 *
 * @example
 * <ReviewStats
 *   stats={{
 *     average_rating: 4.5,
 *     total_reviews: 128,
 *     rating_distribution: { 5: 80, 4: 30, 3: 10, 2: 5, 1: 3 }
 *   }}
 * />
 */
export function ReviewStats({
  stats,
  isLoading = false,
  className,
  compact = false,
}: ReviewStatsProps) {
  if (isLoading) {
    return (
      <div className={className}>
        <div className="sr-only" role="status" aria-live="polite">
          Loading review statistics...
        </div>
        <StatsSkeleton compact={compact} />
      </div>
    );
  }

  // Compact mode: inline display
  if (compact) {
    return (
      <div className={cn("flex items-center gap-2", className)}>
        <span className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          {stats.average_rating.toFixed(1)}
        </span>
        <StarRating rating={stats.average_rating} size="sm" readOnly />
        <span className="text-sm text-gray-500 dark:text-gray-400">
          ({formatReviewCount(stats.total_reviews)})
        </span>
      </div>
    );
  }

  return (
    <div className={cn("space-y-4", className)}>
      <div className="flex flex-col sm:flex-row gap-6 sm:gap-8">
        {/* Average Rating Section */}
        <div className="flex flex-col items-center sm:items-start text-center sm:text-left">
          <div className="text-4xl sm:text-5xl font-bold text-gray-900 dark:text-gray-100">
            {stats.average_rating.toFixed(1)}
          </div>
          <div className="mt-2">
            <StarRating rating={stats.average_rating} size="md" readOnly />
          </div>
          <div className="mt-1 text-sm text-gray-500 dark:text-gray-400">
            {formatReviewCount(stats.total_reviews)}
          </div>
        </div>

        {/* Rating Distribution Section */}
        <div className="flex-1 space-y-2">
          {RATING_LEVELS.map((level) => {
            const count = stats.rating_distribution[level as keyof RatingDistribution] || 0;
            const percentage = calculatePercentage(count, stats.total_reviews);

            return (
              <RatingBar
                key={level}
                level={level}
                count={count}
                percentage={percentage}
              />
            );
          })}
        </div>
      </div>

      {/* Additional Summary (optional) */}
      {stats.total_reviews > 0 && (
        <div className="pt-4 border-t border-gray-200 dark:border-gray-700">
          <p className="text-sm text-gray-600 dark:text-gray-400">
            {stats.rating_distribution[5] + stats.rating_distribution[4] > 0 && (
              <>
                <span className="font-medium text-green-600 dark:text-green-400">
                  {calculatePercentage(
                    stats.rating_distribution[5] + stats.rating_distribution[4],
                    stats.total_reviews
                  )}
                  %
                </span>{" "}
                of reviewers recommend this doctor
              </>
            )}
          </p>
        </div>
      )}
    </div>
  );
}