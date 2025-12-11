import { forwardRef } from 'react';
import type { ComponentPropsWithoutRef } from 'react';
import { cn } from '~/lib/utils';
import { Spinner } from './Spinner';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  /** Visual style variant */
  variant?: ButtonVariant;
  /** Size of the button - all sizes are mobile touch-friendly (min 44px height) */
  size?: ButtonSize;
  /** Show loading spinner and disable interactions */
  isLoading?: boolean;
  /** Loading text for screen readers */
  loadingText?: string;
  /** Full width button */
  fullWidth?: boolean;
}

const variantClasses: Record<ButtonVariant, string> = {
  primary: cn(
    'bg-primary-600 text-white',
    'hover:bg-primary-700 active:bg-primary-800',
    'focus-visible:ring-primary-500',
    'disabled:bg-primary-300'
  ),
  secondary: cn(
    'bg-secondary-600 text-white',
    'hover:bg-secondary-700 active:bg-secondary-800',
    'focus-visible:ring-secondary-500',
    'disabled:bg-secondary-300'
  ),
  outline: cn(
    'border-2 border-primary-600 text-primary-600 bg-transparent',
    'hover:bg-primary-50 active:bg-primary-100',
    'focus-visible:ring-primary-500',
    'disabled:border-primary-300 disabled:text-primary-300'
  ),
  ghost: cn(
    'text-gray-700 bg-transparent',
    'hover:bg-gray-100 active:bg-gray-200',
    'focus-visible:ring-gray-500',
    'disabled:text-gray-400',
    'dark:text-gray-300 dark:hover:bg-gray-800 dark:active:bg-gray-700'
  ),
};

// Mobile-first: All sizes have minimum 44px height for touch targets
const sizeClasses: Record<ButtonSize, string> = {
  sm: 'min-h-[44px] px-3 py-2 text-sm sm:min-h-[36px] sm:px-3 sm:py-1.5',
  md: 'min-h-[44px] px-4 py-2.5 text-base sm:min-h-[40px] sm:px-4 sm:py-2',
  lg: 'min-h-[48px] px-5 py-3 text-lg sm:min-h-[48px] sm:px-6 sm:py-3',
};

/**
 * Accessible, responsive Button component with multiple variants and sizes.
 * Mobile-first design with minimum 44px touch targets.
 *
 * @example
 * <Button variant="primary" size="md">Click Me</Button>
 * <Button variant="secondary" isLoading>Saving...</Button>
 * <Button variant="outline" fullWidth>Full Width</Button>
 */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      children,
      className,
      variant = 'primary',
      size = 'md',
      isLoading = false,
      loadingText = 'Loading',
      fullWidth = false,
      disabled,
      type = 'button',
      ...props
    },
    ref
  ) => {
    const isDisabled = disabled || isLoading;

    return (
      <button
        ref={ref}
        type={type}
        disabled={isDisabled}
        aria-busy={isLoading}
        aria-disabled={isDisabled}
        className={cn(
          // Base styles
          'inline-flex items-center justify-center gap-2',
          'font-medium rounded-lg',
          'transition-colors duration-200',
          // Focus styles
          'focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
          // Disabled styles
          'disabled:cursor-not-allowed',
          // Variant and size
          variantClasses[variant],
          sizeClasses[size],
          // Full width
          fullWidth && 'w-full',
          className
        )}
        {...props}
      >
        {isLoading && (
          <Spinner
            size={size === 'lg' ? 'md' : 'sm'}
            className={cn(
              variant === 'primary' || variant === 'secondary'
                ? 'border-white/30 border-t-white'
                : 'border-primary-200 border-t-primary-600'
            )}
            label={loadingText}
          />
        )}
        <span className={cn(isLoading && 'opacity-70')}>{children}</span>
      </button>
    );
  }
);

Button.displayName = 'Button';
