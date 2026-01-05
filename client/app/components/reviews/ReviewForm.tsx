import { useState, useCallback, useId } from "react";
import { cn } from "~/lib/utils";
import { Button } from "~/components/ui/Button";
import { StarRating } from "./StarRating";
import type { CreateReviewPayload, UpdateReviewPayload } from "~/features/reviews/types";

/**
 * Props for the ReviewForm component.
 */
export interface ReviewFormProps {
  /** Doctor ID for new reviews */
  doctorId?: string;
  /** Appointment ID for new reviews */
  appointmentId?: string;
  /** Initial rating value (for editing) */
  initialRating?: number;
  /** Initial title value (for editing) */
  initialTitle?: string;
  /** Initial comment value (for editing) */
  initialComment?: string;
  /** Whether the form is in edit mode */
  isEditing?: boolean;
  /** Callback when form is submitted */
  onSubmit: (data: CreateReviewPayload | UpdateReviewPayload) => Promise<void>;
  /** Callback when form is cancelled */
  onCancel?: () => void;
  /** Whether the form is currently submitting */
  isLoading?: boolean;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Character limits for review fields.
 */
const TITLE_MAX_LENGTH = 100;
const COMMENT_MAX_LENGTH = 1000;

/**
 * ReviewForm Component
 *
 * A form for submitting or editing doctor reviews.
 * Includes star rating selection, title input, and comment textarea.
 *
 * Features:
 * - Required rating with visual feedback
 * - Optional title and comment fields
 * - Character count for text fields
 * - Form validation with error messages
 * - Loading state during submission
 * - Accessible form controls with proper labels
 *
 * @example
 * // New review
 * <ReviewForm
 *   doctorId="123"
 *   appointmentId="456"
 *   onSubmit={handleSubmit}
 * />
 *
 * // Edit existing review
 * <ReviewForm
 *   isEditing
 *   initialRating={4}
 *   initialTitle="Great doctor"
 *   initialComment="Very thorough examination"
 *   onSubmit={handleUpdate}
 *   onCancel={handleCancel}
 * />
 */
export function ReviewForm({
  doctorId,
  appointmentId,
  initialRating = 0,
  initialTitle = "",
  initialComment = "",
  isEditing = false,
  onSubmit,
  onCancel,
  isLoading = false,
  className,
}: ReviewFormProps) {
  const [rating, setRating] = useState(initialRating);
  const [title, setTitle] = useState(initialTitle);
  const [comment, setComment] = useState(initialComment);
  const [error, setError] = useState<string | null>(null);
  const [touched, setTouched] = useState(false);

  const formId = useId();
  const titleId = `${formId}-title`;
  const commentId = `${formId}-comment`;
  const errorId = `${formId}-error`;

  /**
   * Validate the form and return error message if invalid.
   */
  const validateForm = useCallback((): string | null => {
    if (rating === 0) {
      return "Please select a rating";
    }
    if (rating < 1 || rating > 5) {
      return "Rating must be between 1 and 5";
    }
    if (title.length > TITLE_MAX_LENGTH) {
      return `Title must be ${TITLE_MAX_LENGTH} characters or less`;
    }
    if (comment.length > COMMENT_MAX_LENGTH) {
      return `Comment must be ${COMMENT_MAX_LENGTH} characters or less`;
    }
    return null;
  }, [rating, title, comment]);

  /**
   * Handle form submission.
   */
  const handleSubmit = useCallback(
    async (event: React.FormEvent) => {
      event.preventDefault();
      setTouched(true);

      const validationError = validateForm();
      if (validationError) {
        setError(validationError);
        return;
      }

      setError(null);

      try {
        if (isEditing) {
          await onSubmit({
            rating,
            title: title.trim() || null,
            comment: comment.trim() || null,
          } as UpdateReviewPayload);
        } else {
          if (!doctorId || !appointmentId) {
            setError("Missing doctor or appointment information");
            return;
          }
          await onSubmit({
            doctor_id: doctorId,
            appointment_id: appointmentId,
            rating,
            title: title.trim() || undefined,
            comment: comment.trim() || undefined,
          } as CreateReviewPayload);
        }
      } catch {
        setError("Failed to submit review. Please try again.");
      }
    },
    [
      rating,
      title,
      comment,
      doctorId,
      appointmentId,
      isEditing,
      onSubmit,
      validateForm,
    ]
  );

  /**
   * Handle rating change.
   */
  const handleRatingChange = useCallback((newRating: number) => {
    setRating(newRating);
    setTouched(true);
    // Clear error if rating was the issue
    setError((prev) =>
      prev === "Please select a rating" ? null : prev
    );
  }, []);

  /**
   * Handle title input change.
   */
  const handleTitleChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      const value = event.target.value;
      if (value.length <= TITLE_MAX_LENGTH) {
        setTitle(value);
      }
    },
    []
  );

  /**
   * Handle comment textarea change.
   */
  const handleCommentChange = useCallback(
    (event: React.ChangeEvent<HTMLTextAreaElement>) => {
      const value = event.target.value;
      if (value.length <= COMMENT_MAX_LENGTH) {
        setComment(value);
      }
    },
    []
  );

  const showRatingError = touched && rating === 0;

  return (
    <form
      onSubmit={handleSubmit}
      className={cn("space-y-5", className)}
      noValidate
    >
      {/* Rating Section */}
      <div className="space-y-2">
        <label
          className={cn(
            "block text-sm font-medium",
            showRatingError
              ? "text-error-600 dark:text-error-500"
              : "text-gray-700 dark:text-gray-300"
          )}
        >
          Your Rating
          <span className="text-error-500 ml-1" aria-hidden="true">
            *
          </span>
        </label>
        <StarRating
          rating={rating}
          onChange={handleRatingChange}
          size="lg"
          disabled={isLoading}
          label="Select your rating"
        />
        {showRatingError && (
          <p className="text-sm text-error-600 dark:text-error-500" role="alert">
            Please select a rating
          </p>
        )}
      </div>

      {/* Title Section */}
      <div className="space-y-1.5">
        <label
          htmlFor={titleId}
          className="block text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          Title
          <span className="text-gray-400 ml-1 font-normal">(optional)</span>
        </label>
        <input
          id={titleId}
          type="text"
          value={title}
          onChange={handleTitleChange}
          disabled={isLoading}
          placeholder="Summarize your experience"
          maxLength={TITLE_MAX_LENGTH}
          className={cn(
            "w-full rounded-lg border bg-white transition-colors duration-200",
            "px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm",
            "min-h-[44px] sm:min-h-[40px]",
            "text-gray-900 placeholder:text-gray-400",
            "focus:outline-none focus:ring-2 focus:ring-offset-0",
            "border-gray-300 hover:border-gray-400",
            "focus:border-primary-500 focus:ring-primary-500/20",
            "disabled:opacity-60 disabled:cursor-not-allowed disabled:bg-gray-50",
            "dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700",
            "dark:placeholder:text-gray-500 dark:hover:border-gray-600",
            "dark:focus:border-primary-400"
          )}
        />
        <div className="flex justify-end">
          <span className="text-xs text-gray-500 dark:text-gray-400">
            {title.length}/{TITLE_MAX_LENGTH}
          </span>
        </div>
      </div>

      {/* Comment Section */}
      <div className="space-y-1.5">
        <label
          htmlFor={commentId}
          className="block text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          Your Review
          <span className="text-gray-400 ml-1 font-normal">(optional)</span>
        </label>
        <textarea
          id={commentId}
          value={comment}
          onChange={handleCommentChange}
          disabled={isLoading}
          placeholder="Share details about your experience with this doctor"
          maxLength={COMMENT_MAX_LENGTH}
          rows={4}
          className={cn(
            "w-full rounded-lg border bg-white transition-colors duration-200",
            "px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm",
            "text-gray-900 placeholder:text-gray-400",
            "focus:outline-none focus:ring-2 focus:ring-offset-0",
            "border-gray-300 hover:border-gray-400",
            "focus:border-primary-500 focus:ring-primary-500/20",
            "disabled:opacity-60 disabled:cursor-not-allowed disabled:bg-gray-50",
            "dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700",
            "dark:placeholder:text-gray-500 dark:hover:border-gray-600",
            "dark:focus:border-primary-400",
            "resize-none"
          )}
        />
        <div className="flex justify-end">
          <span className="text-xs text-gray-500 dark:text-gray-400">
            {comment.length}/{COMMENT_MAX_LENGTH}
          </span>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div
          id={errorId}
          role="alert"
          className={cn(
            "p-3 rounded-lg",
            "bg-error-50 border border-error-200",
            "text-sm text-error-700",
            "dark:bg-error-900/20 dark:border-error-800 dark:text-error-400"
          )}
        >
          {error}
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        {onCancel && (
          <Button
            type="button"
            variant="outline"
            onClick={onCancel}
            disabled={isLoading}
            className="sm:w-auto"
          >
            Cancel
          </Button>
        )}
        <Button
          type="submit"
          variant="primary"
          isLoading={isLoading}
          loadingText="Submitting"
          className="sm:w-auto"
        >
          {isEditing ? "Update Review" : "Submit Review"}
        </Button>
      </div>
    </form>
  );
}