import { useState, useCallback, useId } from "react";
import { cn } from "~/lib/utils";

/**
 * Size variants for the star rating component.
 */
export type StarSize = "sm" | "md" | "lg" | "xl";

/**
 * Props for the StarRating component.
 */
export interface StarRatingProps {
  /** Current rating value (1-5) */
  rating: number;
  /** Maximum rating value (default: 5) */
  maxRating?: number;
  /** Size of the stars */
  size?: StarSize;
  /** Callback when rating changes (makes component interactive) */
  onChange?: (rating: number) => void;
  /** Whether the rating is read-only (display mode) */
  readOnly?: boolean;
  /** Whether the component is disabled */
  disabled?: boolean;
  /** Additional CSS classes */
  className?: string;
  /** Show numeric rating value alongside stars */
  showValue?: boolean;
  /** Label for accessibility */
  label?: string;
}

/**
 * Size classes for different star sizes.
 */
const sizeClasses: Record<StarSize, string> = {
  sm: "w-4 h-4",
  md: "w-5 h-5",
  lg: "w-6 h-6",
  xl: "w-8 h-8",
};

/**
 * Gap classes between stars for different sizes.
 */
const gapClasses: Record<StarSize, string> = {
  sm: "gap-0.5",
  md: "gap-1",
  lg: "gap-1",
  xl: "gap-1.5",
};

/**
 * Text size for showing the numeric value.
 */
const valueSizeClasses: Record<StarSize, string> = {
  sm: "text-xs",
  md: "text-sm",
  lg: "text-base",
  xl: "text-lg",
};

/**
 * Star icon component with fill support.
 */
function StarIcon({
  filled,
  halfFilled,
  className,
}: {
  filled: boolean;
  halfFilled?: boolean;
  className?: string;
}) {
  if (halfFilled) {
    return (
      <svg
        className={className}
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <defs>
          <linearGradient id="halfFill">
            <stop offset="50%" stopColor="currentColor" />
            <stop offset="50%" stopColor="transparent" />
          </linearGradient>
        </defs>
        <path
          d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"
          fill="url(#halfFill)"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }

  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill={filled ? "currentColor" : "none"}
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/**
 * StarRating Component
 *
 * A dual-mode star rating component that can be used for both display and input.
 * - Display mode: Shows filled/empty stars for a given rating
 * - Input mode: Clickable stars for rating selection with hover preview
 *
 * Features:
 * - Keyboard accessible (arrow keys, Enter, Tab)
 * - Screen reader friendly with ARIA labels
 * - Hover preview in input mode
 * - Supports half-star display for average ratings
 * - Multiple size variants
 *
 * @example
 * // Display mode
 * <StarRating rating={4.5} readOnly />
 *
 * // Input mode
 * <StarRating rating={rating} onChange={setRating} />
 */
export function StarRating({
  rating,
  maxRating = 5,
  size = "md",
  onChange,
  readOnly = false,
  disabled = false,
  className,
  showValue = false,
  label = "Rating",
}: StarRatingProps) {
  const [hoverRating, setHoverRating] = useState<number | null>(null);
  const groupId = useId();

  const isInteractive = !readOnly && !disabled && onChange;
  const displayRating = hoverRating ?? rating;

  /**
   * Handle star click to set rating.
   */
  const handleClick = useCallback(
    (value: number) => {
      if (isInteractive) {
        onChange(value);
      }
    },
    [isInteractive, onChange]
  );

  /**
   * Handle mouse enter for hover preview.
   */
  const handleMouseEnter = useCallback(
    (value: number) => {
      if (isInteractive) {
        setHoverRating(value);
      }
    },
    [isInteractive]
  );

  /**
   * Handle mouse leave to reset hover state.
   */
  const handleMouseLeave = useCallback(() => {
    setHoverRating(null);
  }, []);

  /**
   * Handle keyboard navigation.
   */
  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent, currentValue: number) => {
      if (!isInteractive) return;

      let newValue = currentValue;

      switch (event.key) {
        case "ArrowRight":
        case "ArrowUp":
          event.preventDefault();
          newValue = Math.min(currentValue + 1, maxRating);
          break;
        case "ArrowLeft":
        case "ArrowDown":
          event.preventDefault();
          newValue = Math.max(currentValue - 1, 1);
          break;
        case "Home":
          event.preventDefault();
          newValue = 1;
          break;
        case "End":
          event.preventDefault();
          newValue = maxRating;
          break;
        case "Enter":
        case " ":
          event.preventDefault();
          onChange(currentValue);
          return;
        default:
          return;
      }

      if (newValue !== currentValue) {
        onChange(newValue);
      }
    },
    [isInteractive, maxRating, onChange]
  );

  /**
   * Determine if a star should be filled based on the current rating.
   * Supports half-star display for decimal ratings.
   */
  const getStarFill = (starIndex: number): { filled: boolean; halfFilled: boolean } => {
    const starValue = starIndex + 1;
    const effectiveRating = displayRating;

    if (effectiveRating >= starValue) {
      return { filled: true, halfFilled: false };
    }

    if (effectiveRating >= starValue - 0.5 && readOnly) {
      return { filled: false, halfFilled: true };
    }

    return { filled: false, halfFilled: false };
  };

  /**
   * Generate accessibility label for the rating.
   */
  const getAriaLabel = (): string => {
    if (isInteractive) {
      return `${label}: ${rating} out of ${maxRating} stars. Use arrow keys to change rating.`;
    }
    return `${label}: ${rating} out of ${maxRating} stars`;
  };

  const stars = Array.from({ length: maxRating }, (_, index) => {
    const starValue = index + 1;
    const { filled, halfFilled } = getStarFill(index);

    if (isInteractive) {
      return (
        <button
          key={index}
          type="button"
          onClick={() => handleClick(starValue)}
          onMouseEnter={() => handleMouseEnter(starValue)}
          onKeyDown={(e) => handleKeyDown(e, starValue)}
          className={cn(
            "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500",
            "focus-visible:ring-offset-1 rounded-sm",
            "transition-transform duration-100",
            "hover:scale-110",
            filled
              ? "text-yellow-400"
              : "text-gray-300 dark:text-gray-600"
          )}
          aria-label={`Rate ${starValue} out of ${maxRating} stars`}
          tabIndex={starValue === Math.round(rating) || (rating === 0 && starValue === 1) ? 0 : -1}
        >
          <StarIcon
            filled={filled}
            halfFilled={halfFilled}
            className={sizeClasses[size]}
          />
        </button>
      );
    }

    return (
      <span
        key={index}
        className={cn(
          filled || halfFilled
            ? "text-yellow-400"
            : "text-gray-300 dark:text-gray-600"
        )}
      >
        <StarIcon
          filled={filled}
          halfFilled={halfFilled}
          className={sizeClasses[size]}
        />
      </span>
    );
  });

  return (
    <div
      role={isInteractive ? "radiogroup" : "img"}
      aria-label={getAriaLabel()}
      className={cn(
        "inline-flex items-center",
        gapClasses[size],
        disabled && "opacity-50 cursor-not-allowed",
        className
      )}
      onMouseLeave={handleMouseLeave}
      id={groupId}
    >
      {stars}
      {showValue && (
        <span
          className={cn(
            "ml-1.5 font-medium text-gray-700 dark:text-gray-300",
            valueSizeClasses[size]
          )}
        >
          {rating.toFixed(1)}
        </span>
      )}
    </div>
  );
}