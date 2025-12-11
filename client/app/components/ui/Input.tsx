import { forwardRef, useId } from 'react';
import type { ComponentPropsWithoutRef } from 'react';
import { cn } from '~/lib/utils';

export interface InputProps extends ComponentPropsWithoutRef<'input'> {
  /** Label displayed above the input */
  label?: string;
  /** Error message to display below the input */
  error?: string;
  /** Helper text displayed below the input (hidden when error is present) */
  helperText?: string;
  /** Additional classes for the input wrapper */
  wrapperClassName?: string;
}

/**
 * Accessible, responsive Input component with label and error handling.
 * Full width on mobile, can be constrained on desktop via wrapper.
 *
 * @example
 * <Input label="Email" type="email" placeholder="you@example.com" />
 * <Input label="Password" type="password" error="Password is required" />
 * <Input label="Username" helperText="Must be at least 3 characters" />
 */
export const Input = forwardRef<HTMLInputElement, InputProps>(
  (
    {
      label,
      error,
      helperText,
      className,
      wrapperClassName,
      id,
      disabled,
      required,
      ...props
    },
    ref
  ) => {
    // Generate unique ID for accessibility if not provided
    const generatedId = useId();
    const inputId = id || generatedId;
    const errorId = `${inputId}-error`;
    const helperId = `${inputId}-helper`;

    const hasError = Boolean(error);

    return (
      <div className={cn('w-full', wrapperClassName)}>
        {/* Label */}
        {label && (
          <label
            htmlFor={inputId}
            className={cn(
              'block text-sm font-medium mb-1.5',
              'text-gray-700 dark:text-gray-300',
              hasError && 'text-error-600 dark:text-error-500',
              disabled && 'opacity-60'
            )}
          >
            {label}
            {required && (
              <span className="text-error-500 ml-1" aria-hidden="true">
                *
              </span>
            )}
          </label>
        )}

        {/* Input field */}
        <input
          ref={ref}
          id={inputId}
          disabled={disabled}
          required={required}
          aria-invalid={hasError}
          aria-describedby={
            hasError ? errorId : helperText ? helperId : undefined
          }
          className={cn(
            // Base styles
            'w-full rounded-lg border bg-white transition-colors duration-200',
            // Responsive padding - larger touch targets on mobile
            'px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm',
            // Min height for touch accessibility
            'min-h-[44px] sm:min-h-[40px]',
            // Text styles
            'text-gray-900 placeholder:text-gray-400',
            // Focus styles
            'focus:outline-none focus:ring-2 focus:ring-offset-0',
            // Default border
            !hasError && [
              'border-gray-300',
              'hover:border-gray-400',
              'focus:border-primary-500 focus:ring-primary-500/20',
            ],
            // Error border
            hasError && [
              'border-error-500',
              'focus:border-error-500 focus:ring-error-500/20',
            ],
            // Disabled styles
            disabled && 'opacity-60 cursor-not-allowed bg-gray-50',
            // Dark mode
            'dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700',
            'dark:placeholder:text-gray-500',
            'dark:hover:border-gray-600',
            !hasError && 'dark:focus:border-primary-400',
            className
          )}
          {...props}
        />

        {/* Error message */}
        {hasError && (
          <p
            id={errorId}
            role="alert"
            className="mt-1.5 text-sm text-error-600 dark:text-error-500"
          >
            {error}
          </p>
        )}

        {/* Helper text (hidden when error is shown) */}
        {!hasError && helperText && (
          <p
            id={helperId}
            className="mt-1.5 text-sm text-gray-500 dark:text-gray-400"
          >
            {helperText}
          </p>
        )}
      </div>
    );
  }
);

Input.displayName = 'Input';
