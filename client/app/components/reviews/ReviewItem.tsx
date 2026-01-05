import { useState, useCallback } from "react";
import { cn } from "~/lib/utils";
import { StarRating } from "./StarRating";
import type { Review } from "~/features/reviews/types";

/**
 * Props for the ReviewItem component.
 */
export interface ReviewItemProps {
  /** The review data to display */
  review: Review;
  /** Callback when user votes on the review */
  onVote?: (reviewId: string, vote: "helpful" | "not_helpful") => Promise<void>;
  /** Callback when user removes their vote */
  onRemoveVote?: (reviewId: string) => Promise<void>;
  /** Whether the current user is the author of this review */
  isOwnReview?: boolean;
  /** Callback to edit the review (only for own reviews) */
  onEdit?: (review: Review) => void;
  /** Callback to delete the review (only for own reviews) */
  onDelete?: (reviewId: string) => Promise<void>;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Format a date string to a readable format.
 */
function formatDate(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    return "Today";
  } else if (diffDays === 1) {
    return "Yesterday";
  } else if (diffDays < 7) {
    return `${diffDays} days ago`;
  } else if (diffDays < 30) {
    const weeks = Math.floor(diffDays / 7);
    return `${weeks} ${weeks === 1 ? "week" : "weeks"} ago`;
  } else if (diffDays < 365) {
    const months = Math.floor(diffDays / 30);
    return `${months} ${months === 1 ? "month" : "months"} ago`;
  } else {
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }
}

/**
 * Generate initials from a name for avatar fallback.
 */
function getInitials(name: string): string {
  return name
    .split(" ")
    .map((part) => part[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

/**
 * Thumbs up icon component.
 */
function ThumbsUpIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3zM7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3" />
    </svg>
  );
}

/**
 * Thumbs down icon component.
 */
function ThumbsDownIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M10 15v4a3 3 0 0 0 3 3l4-9V2H5.72a2 2 0 0 0-2 1.7l-1.38 9a2 2 0 0 0 2 2.3zm7-13h2.67A2.31 2.31 0 0 1 22 4v7a2.31 2.31 0 0 1-2.33 2H17" />
    </svg>
  );
}

/**
 * Verified badge icon component.
 */
function VerifiedIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        fillRule="evenodd"
        d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.497 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z"
        clipRule="evenodd"
      />
    </svg>
  );
}

/**
 * ReviewItem Component
 *
 * Displays an individual review with patient info, rating, title, comment, and date.
 * Supports helpful/not helpful voting and edit/delete actions for own reviews.
 *
 * Features:
 * - Patient avatar with fallback initials
 * - Star rating display
 * - Verified badge for completed appointment reviews
 * - Relative date formatting
 * - Helpful/not helpful voting buttons
 * - Edit and delete actions for own reviews
 * - Accessible button interactions
 *
 * @example
 * <ReviewItem
 *   review={review}
 *   onVote={handleVote}
 *   onRemoveVote={handleRemoveVote}
 * />
 */
export function ReviewItem({
  review,
  onVote,
  onRemoveVote,
  isOwnReview = false,
  onEdit,
  onDelete,
  className,
}: ReviewItemProps) {
  const [isVoting, setIsVoting] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  /**
   * Handle voting on the review.
   */
  const handleVote = useCallback(
    async (vote: "helpful" | "not_helpful") => {
      if (!onVote || isVoting) return;

      setIsVoting(true);
      try {
        // If user already voted the same way, remove the vote
        if (review.user_vote === vote && onRemoveVote) {
          await onRemoveVote(review.id);
        } else {
          await onVote(review.id, vote);
        }
      } finally {
        setIsVoting(false);
      }
    },
    [onVote, onRemoveVote, review.id, review.user_vote, isVoting]
  );

  /**
   * Handle deleting the review.
   */
  const handleDelete = useCallback(async () => {
    if (!onDelete || isDeleting) return;

    if (!window.confirm("Are you sure you want to delete this review?")) {
      return;
    }

    setIsDeleting(true);
    try {
      await onDelete(review.id);
    } finally {
      setIsDeleting(false);
    }
  }, [onDelete, review.id, isDeleting]);

  return (
    <article
      className={cn(
        "p-4 sm:p-5",
        "border-b border-gray-200 dark:border-gray-700",
        "last:border-b-0",
        className
      )}
      aria-label={`Review by ${review.patient_name}`}
    >
      {/* Header: Avatar, Name, Verified Badge, Date */}
      <div className="flex items-start gap-3 sm:gap-4">
        {/* Avatar */}
        <div
          className={cn(
            "flex-shrink-0 w-10 h-10 sm:w-12 sm:h-12",
            "rounded-full overflow-hidden",
            "bg-primary-100 dark:bg-primary-900",
            "flex items-center justify-center"
          )}
        >
          {review.patient_avatar ? (
            <img
              src={review.patient_avatar}
              alt=""
              className="w-full h-full object-cover"
            />
          ) : (
            <span className="text-sm sm:text-base font-medium text-primary-600 dark:text-primary-400">
              {getInitials(review.patient_name)}
            </span>
          )}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          {/* Name, Verified Badge, Rating, Date */}
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span className="font-medium text-gray-900 dark:text-gray-100">
              {review.patient_name}
            </span>
            {review.is_verified && (
              <span
                className="inline-flex items-center gap-0.5 text-xs text-green-600 dark:text-green-400"
                title="Verified patient"
              >
                <VerifiedIcon className="w-4 h-4" />
                <span className="sr-only sm:not-sr-only">Verified</span>
              </span>
            )}
            <span className="text-gray-400 dark:text-gray-500">-</span>
            <span className="text-sm text-gray-500 dark:text-gray-400">
              {formatDate(review.created_at)}
            </span>
          </div>

          {/* Star Rating */}
          <div className="mt-1">
            <StarRating rating={review.rating} size="sm" readOnly />
          </div>

          {/* Title */}
          {review.title && (
            <h4 className="mt-2 font-medium text-gray-900 dark:text-gray-100">
              {review.title}
            </h4>
          )}

          {/* Comment */}
          {review.comment && (
            <p className="mt-1 text-gray-600 dark:text-gray-400 whitespace-pre-wrap">
              {review.comment}
            </p>
          )}

          {/* Actions: Helpful buttons or Edit/Delete */}
          <div className="mt-3 flex flex-wrap items-center gap-3">
            {isOwnReview ? (
              <>
                {onEdit && (
                  <button
                    type="button"
                    onClick={() => onEdit(review)}
                    className={cn(
                      "text-sm text-primary-600 hover:text-primary-700",
                      "dark:text-primary-400 dark:hover:text-primary-300",
                      "focus:outline-none focus-visible:underline"
                    )}
                  >
                    Edit
                  </button>
                )}
                {onDelete && (
                  <button
                    type="button"
                    onClick={handleDelete}
                    disabled={isDeleting}
                    className={cn(
                      "text-sm text-error-600 hover:text-error-700",
                      "dark:text-error-400 dark:hover:text-error-300",
                      "focus:outline-none focus-visible:underline",
                      "disabled:opacity-50 disabled:cursor-not-allowed"
                    )}
                  >
                    {isDeleting ? "Deleting..." : "Delete"}
                  </button>
                )}
              </>
            ) : (
              <>
                {onVote && (
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-500 dark:text-gray-400">
                      Was this helpful?
                    </span>
                    <button
                      type="button"
                      onClick={() => handleVote("helpful")}
                      disabled={isVoting}
                      className={cn(
                        "inline-flex items-center gap-1 px-2 py-1 rounded",
                        "text-sm transition-colors",
                        "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500",
                        review.user_vote === "helpful"
                          ? "text-green-600 bg-green-50 dark:text-green-400 dark:bg-green-900/20"
                          : "text-gray-500 hover:text-green-600 hover:bg-green-50 dark:text-gray-400 dark:hover:text-green-400 dark:hover:bg-green-900/20",
                        "disabled:opacity-50 disabled:cursor-not-allowed"
                      )}
                      aria-label={`Mark as helpful (${review.helpful_count} votes)`}
                      aria-pressed={review.user_vote === "helpful"}
                    >
                      <ThumbsUpIcon className="w-4 h-4" />
                      <span>{review.helpful_count}</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleVote("not_helpful")}
                      disabled={isVoting}
                      className={cn(
                        "inline-flex items-center gap-1 px-2 py-1 rounded",
                        "text-sm transition-colors",
                        "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500",
                        review.user_vote === "not_helpful"
                          ? "text-red-600 bg-red-50 dark:text-red-400 dark:bg-red-900/20"
                          : "text-gray-500 hover:text-red-600 hover:bg-red-50 dark:text-gray-400 dark:hover:text-red-400 dark:hover:bg-red-900/20",
                        "disabled:opacity-50 disabled:cursor-not-allowed"
                      )}
                      aria-label={`Mark as not helpful (${review.not_helpful_count} votes)`}
                      aria-pressed={review.user_vote === "not_helpful"}
                    >
                      <ThumbsDownIcon className="w-4 h-4" />
                      <span>{review.not_helpful_count}</span>
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </article>
  );
}