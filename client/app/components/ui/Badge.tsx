import type { ReactNode } from 'react';
import { cn } from '~/lib/utils';

export type BadgeVariant =
  | 'default'
  | 'success'
  | 'warning'
  | 'error'
  | 'info'
  | 'primary';

export type BadgeSize = 'sm' | 'md' | 'lg';

export interface BadgeProps {
  /** Badge content */
  children: ReactNode;
  /** Visual variant */
  variant?: BadgeVariant;
  /** Size of the badge */
  size?: BadgeSize;
  /** Optional icon to display before the text */
  icon?: ReactNode;
  /** Show a status dot indicator */
  dot?: boolean;
  /** Additional CSS classes */
  className?: string;
}

const variantClasses: Record<BadgeVariant, string> = {
  default: cn(
    'bg-gray-100 text-gray-700',
    'dark:bg-gray-800 dark:text-gray-300'
  ),
  success: cn(
    'bg-success-100 text-success-700',
    'dark:bg-success-900/30 dark:text-success-400'
  ),
  warning: cn(
    'bg-warning-100 text-warning-700',
    'dark:bg-warning-900/30 dark:text-warning-400'
  ),
  error: cn(
    'bg-error-100 text-error-700',
    'dark:bg-error-900/30 dark:text-error-400'
  ),
  info: cn(
    'bg-info-100 text-info-700',
    'dark:bg-info-900/30 dark:text-info-400'
  ),
  primary: cn(
    'bg-primary-100 text-primary-700',
    'dark:bg-primary-900/30 dark:text-primary-400'
  ),
};

const dotColorClasses: Record<BadgeVariant, string> = {
  default: 'bg-gray-500 dark:bg-gray-400',
  success: 'bg-success-500 dark:bg-success-400',
  warning: 'bg-warning-500 dark:bg-warning-400',
  error: 'bg-error-500 dark:bg-error-400',
  info: 'bg-info-500 dark:bg-info-400',
  primary: 'bg-primary-500 dark:bg-primary-400',
};

const sizeClasses: Record<BadgeSize, string> = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-2.5 py-1 text-xs',
  lg: 'px-3 py-1 text-sm',
};

const dotSizeClasses: Record<BadgeSize, string> = {
  sm: 'w-1.5 h-1.5',
  md: 'w-2 h-2',
  lg: 'w-2 h-2',
};

/**
 * Badge component for status indicators, labels, and tags.
 * Supports multiple variants, sizes, icons, and status dots.
 *
 * @example
 * <Badge variant="success">Active</Badge>
 * <Badge variant="error" size="sm">Urgent</Badge>
 * <Badge variant="info" dot>Online</Badge>
 * <Badge variant="primary" icon={<StarIcon />}>Featured</Badge>
 */
export function Badge({
  children,
  variant = 'default',
  size = 'md',
  icon,
  dot = false,
  className,
}: BadgeProps) {
  return (
    <span
      className={cn(
        // Base styles
        'inline-flex items-center gap-1.5',
        'font-medium rounded-full',
        'whitespace-nowrap',
        // Variant and size
        variantClasses[variant],
        sizeClasses[size],
        className
      )}
    >
      {/* Status dot */}
      {dot && (
        <span
          className={cn(
            'rounded-full flex-shrink-0',
            dotSizeClasses[size],
            dotColorClasses[variant]
          )}
          aria-hidden="true"
        />
      )}

      {/* Icon */}
      {icon && (
        <span className="flex-shrink-0 [&>svg]:w-3.5 [&>svg]:h-3.5" aria-hidden="true">
          {icon}
        </span>
      )}

      {/* Text content */}
      {children}
    </span>
  );
}