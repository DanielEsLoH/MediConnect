import { cn } from '~/lib/utils';

export interface SpinnerProps {
  /** Size variant for the spinner */
  size?: 'sm' | 'md' | 'lg';
  /** Additional CSS classes */
  className?: string;
  /** Whether to center the spinner in its container */
  center?: boolean;
  /** Accessible label for screen readers */
  label?: string;
}

const sizeClasses = {
  sm: 'h-4 w-4 border-2',
  md: 'h-6 w-6 border-2',
  lg: 'h-8 w-8 border-3',
} as const;

/**
 * Spinner component for loading states.
 * Animated rotating circle with primary blue color.
 *
 * @example
 * <Spinner size="md" />
 * <Spinner size="lg" center />
 */
export function Spinner({
  size = 'md',
  className,
  center = false,
  label = 'Loading',
}: SpinnerProps) {
  const spinner = (
    <div
      role="status"
      aria-label={label}
      className={cn(
        'animate-spin rounded-full border-primary-200 border-t-primary-600',
        sizeClasses[size],
        className
      )}
    >
      <span className="sr-only">{label}</span>
    </div>
  );

  if (center) {
    return (
      <div className="flex items-center justify-center w-full h-full min-h-[100px]">
        {spinner}
      </div>
    );
  }

  return spinner;
}
