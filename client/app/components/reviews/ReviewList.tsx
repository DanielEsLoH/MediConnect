import { cn } from "~/lib/utils";
import { Button } from "~/components/ui/Button";
import { ReviewItem } from "./ReviewItem";
import type { Review, ReviewPaginationMeta } from "~/features/reviews/types";

/**
 * Props for the ReviewList component.
 */
export interface ReviewListProps {
  /** Array of reviews to display */
  reviews: Review[];
  /** Pagination metadata */
  meta?: ReviewPaginationMeta;
  /** Whether reviews are currently loading */
  isLoading?: boolean;
  /** Whether more reviews are being loaded */
  isLoadingMore?: boolean;
  /** Error message if loading failed */
  error?: string | null;
  /** Callback to load more reviews */
  onLoadMore?: () => void;
  /** Callback when user votes on a review */
  onVote?: (reviewId: string, vote: "helpful" | "not_helpful") => Promise<void>;
  /** Callback when user removes their vote */
  onRemoveVote?: (reviewId: string) => Promise<void>;
  /** ID of the current user (to identify own reviews) */
  currentUserId?: string;
  /** Callback to edit a review */
  onEditReview?: (review: Review) => void;
  /** Callback to delete a review */
  onDeleteReview?: (reviewId: string) => Promise<void>;
  /** Additional CSS classes */
  className?: string;
  /** Empty state message */
  emptyMessage?: string;
  /** Empty state description */
  emptyDescription?: string;
}

/**
 * Loading skeleton for a single review.
 */
function ReviewSkeleton() {
  return (
    <div className="p-4 sm:p-5 animate-pulse" aria-hidden="true">
      <div className="flex items-start gap-3 sm:gap-4">
        {/* Avatar skeleton */}
        <div className="flex-shrink-0 w-10 h-10 sm:w-12 sm:h-12 rounded-full bg-gray-200 dark:bg-gray-700" />

        {/* Content skeleton */}
        <div className="flex-1 space-y-3">
          {/* Name and date */}
          <div className="flex items-center gap-2">
            <div className="h-4 w-24 bg-gray-200 dark:bg-gray-700 rounded" />
            <div className="h-4 w-16 bg-gray-200 dark:bg-gray-700 rounded" />
          </div>

          {/* Stars */}
          <div className="flex gap-1">
            {Array.from({ length: 5 }).map((_, i) => (
              <div
                key={i}
                className="w-4 h-4 bg-gray-200 dark:bg-gray-700 rounded"
              />
            ))}
          </div>

          {/* Title */}
          <div className="h-4 w-3/4 bg-gray-200 dark:bg-gray-700 rounded" />

          {/* Comment lines */}
          <div className="space-y-2">
            <div className="h-3 w-full bg-gray-200 dark:bg-gray-700 rounded" />
            <div className="h-3 w-5/6 bg-gray-200 dark:bg-gray-700 rounded" />
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * Empty state component when no reviews exist.
 */
function EmptyState({
  message,
  description,
}: {
  message: string;
  description?: string;
}) {
  return (
    <div className="py-12 px-4 text-center">
      {/* Empty state icon */}
      <svg
        className="mx-auto w-12 h-12 text-gray-400 dark:text-gray-500"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        aria-hidden="true"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
        />
      </svg>
      <h3 className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">
        {message}
      </h3>
      {description && (
        <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
          {description}
        </p>
      )}
    </div>
  );
}

/**
 * Error state component when loading fails.
 */
function ErrorState({ message }: { message: string }) {
  return (
    <div className="py-12 px-4 text-center">
      <svg
        className="mx-auto w-12 h-12 text-error-400 dark:text-error-500"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        aria-hidden="true"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
        />
      </svg>
      <h3 className="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">
        Failed to load reviews
      </h3>
      <p className="mt-2 text-sm text-error-600 dark:text-error-400">
        {message}
      </p>
    </div>
  );
}

/**
 * ReviewList Component
 *
 * Displays a list of reviews with loading states, pagination, and empty/error states.
 *
 * Features:
 * - Loading skeleton animation
 * - Empty state with custom message
 * - Error state display
 * - Pagination with "Load More" button
 * - Vote handling delegation to ReviewItem
 * - Edit/delete actions for own reviews
 *
 * @example
 * <ReviewList
 *   reviews={reviews}
 *   meta={meta}
 *   isLoading={isLoading}
 *   onLoadMore={loadMore}
 *   onVote={handleVote}
 *   currentUserId={userId}
 * />
 */
export function ReviewList({
  reviews,
  meta,
  isLoading = false,
  isLoadingMore = false,
  error = null,
  onLoadMore,
  onVote,
  onRemoveVote,
  currentUserId,
  onEditReview,
  onDeleteReview,
  className,
  emptyMessage = "No reviews yet",
  emptyDescription = "Be the first to share your experience with this doctor.",
}: ReviewListProps) {
  // Show loading skeletons on initial load
  if (isLoading && reviews.length === 0) {
    return (
      <div className={cn("divide-y divide-gray-200 dark:divide-gray-700", className)}>
        <div className="sr-only" role="status" aria-live="polite">
          Loading reviews...
        </div>
        {Array.from({ length: 3 }).map((_, index) => (
          <ReviewSkeleton key={index} />
        ))}
      </div>
    );
  }

  // Show error state
  if (error) {
    return (
      <div className={className}>
        <ErrorState message={error} />
      </div>
    );
  }

  // Show empty state
  if (reviews.length === 0) {
    return (
      <div className={className}>
        <EmptyState message={emptyMessage} description={emptyDescription} />
      </div>
    );
  }

  const hasMorePages = meta ? meta.page < meta.total_pages : false;

  return (
    <div className={className}>
      {/* Reviews list */}
      <div
        className="divide-y divide-gray-200 dark:divide-gray-700"
        role="feed"
        aria-label="Reviews"
      >
        {reviews.map((review) => (
          <ReviewItem
            key={review.id}
            review={review}
            onVote={onVote}
            onRemoveVote={onRemoveVote}
            isOwnReview={currentUserId === review.patient_id}
            onEdit={onEditReview}
            onDelete={onDeleteReview}
          />
        ))}
      </div>

      {/* Loading more indicator */}
      {isLoadingMore && (
        <div className="py-4">
          <ReviewSkeleton />
        </div>
      )}

      {/* Load more button */}
      {hasMorePages && onLoadMore && !isLoadingMore && (
        <div className="py-4 px-4 sm:px-5 text-center">
          <Button
            variant="outline"
            onClick={onLoadMore}
            disabled={isLoadingMore}
            isLoading={isLoadingMore}
            loadingText="Loading more reviews"
          >
            Load More Reviews
          </Button>
        </div>
      )}

      {/* Pagination info */}
      {meta && (
        <div className="py-3 px-4 sm:px-5 text-center">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Showing {reviews.length} of {meta.total} reviews
          </p>
        </div>
      )}
    </div>
  );
}
