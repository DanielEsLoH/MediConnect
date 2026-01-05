import {
  forwardRef,
  useId,
  useRef,
  useEffect,
  useCallback,
  type ComponentPropsWithoutRef,
  type ChangeEvent,
} from 'react';
import { cn } from '~/lib/utils';

export interface TextareaProps
  extends Omit<ComponentPropsWithoutRef<'textarea'>, 'onChange'> {
  /** Label displayed above the textarea */
  label?: string;
  /** Error message to display below the textarea */
  error?: string;
  /** Helper text displayed below the textarea (hidden when error is present) */
  helperText?: string;
  /** Additional classes for the textarea wrapper */
  wrapperClassName?: string;
  /** Show character count */
  showCharCount?: boolean;
  /** Maximum character count (also sets maxLength) */
  maxCharCount?: number;
  /** Enable auto-resize based on content */
  autoResize?: boolean;
  /** Minimum number of rows (default: 3) */
  minRows?: number;
  /** Maximum number of rows for auto-resize */
  maxRows?: number;
  /** Custom onChange handler */
  onChange?: (value: string, event: ChangeEvent<HTMLTextAreaElement>) => void;
}

/**
 * Accessible, responsive Textarea component with label and error handling.
 * Supports character counting and auto-resize features.
 *
 * @example
 * <Textarea label="Description" placeholder="Enter a description..." />
 * <Textarea label="Bio" showCharCount maxCharCount={500} />
 * <Textarea label="Notes" autoResize minRows={2} maxRows={10} />
 * <Textarea label="Comment" error="This field is required" />
 */
export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
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
      showCharCount = false,
      maxCharCount,
      autoResize = false,
      minRows = 3,
      maxRows = 10,
      value,
      defaultValue,
      onChange,
      ...props
    },
    ref
  ) => {
    // Generate unique ID for accessibility if not provided
    const generatedId = useId();
    const textareaId = id || generatedId;
    const errorId = `${textareaId}-error`;
    const helperId = `${textareaId}-helper`;
    const counterId = `${textareaId}-counter`;

    const hasError = Boolean(error);
    const internalRef = useRef<HTMLTextAreaElement>(null);
    const textareaRef = (ref as React.RefObject<HTMLTextAreaElement>) || internalRef;

    // Calculate character count
    const currentLength =
      typeof value === 'string'
        ? value.length
        : typeof defaultValue === 'string'
        ? defaultValue.length
        : 0;

    const isOverLimit = maxCharCount !== undefined && currentLength > maxCharCount;

    // Auto-resize logic
    const adjustHeight = useCallback(() => {
      const textarea = textareaRef.current;
      if (!textarea || !autoResize) return;

      // Reset height to calculate scrollHeight
      textarea.style.height = 'auto';

      // Calculate line height
      const computedStyle = window.getComputedStyle(textarea);
      const lineHeight = parseFloat(computedStyle.lineHeight) || 20;
      const paddingTop = parseFloat(computedStyle.paddingTop) || 0;
      const paddingBottom = parseFloat(computedStyle.paddingBottom) || 0;
      const borderTop = parseFloat(computedStyle.borderTopWidth) || 0;
      const borderBottom = parseFloat(computedStyle.borderBottomWidth) || 0;

      const minHeight = lineHeight * minRows + paddingTop + paddingBottom + borderTop + borderBottom;
      const maxHeight = lineHeight * maxRows + paddingTop + paddingBottom + borderTop + borderBottom;

      // Set new height
      const newHeight = Math.min(Math.max(textarea.scrollHeight, minHeight), maxHeight);
      textarea.style.height = `${newHeight}px`;
    }, [autoResize, maxRows, minRows, textareaRef]);

    // Adjust height on mount and value change
    useEffect(() => {
      if (autoResize) {
        adjustHeight();
      }
    }, [adjustHeight, autoResize, value]);

    // Handle change
    const handleChange = useCallback(
      (event: ChangeEvent<HTMLTextAreaElement>) => {
        onChange?.(event.target.value, event);
        if (autoResize) {
          adjustHeight();
        }
      },
      [adjustHeight, autoResize, onChange]
    );

    // Build aria-describedby
    const ariaDescribedBy = [
      hasError ? errorId : null,
      !hasError && helperText ? helperId : null,
      showCharCount ? counterId : null,
    ]
      .filter(Boolean)
      .join(' ') || undefined;

    return (
      <div className={cn('w-full', wrapperClassName)}>
        {/* Label */}
        {label && (
          <label
            htmlFor={textareaId}
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

        {/* Textarea field */}
        <textarea
          ref={textareaRef}
          id={textareaId}
          disabled={disabled}
          required={required}
          aria-invalid={hasError}
          aria-describedby={ariaDescribedBy}
          rows={autoResize ? minRows : minRows}
          maxLength={maxCharCount}
          value={value}
          defaultValue={defaultValue}
          onChange={handleChange}
          className={cn(
            // Base styles
            'w-full rounded-lg border bg-white transition-colors duration-200',
            // Responsive padding
            'px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm',
            // Text styles
            'text-gray-900 placeholder:text-gray-400',
            // Resize
            autoResize ? 'resize-none overflow-hidden' : 'resize-y',
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

        {/* Bottom row: error/helper text and character count */}
        <div className="flex justify-between items-start mt-1.5 gap-4">
          <div className="flex-1 min-w-0">
            {/* Error message */}
            {hasError && (
              <p
                id={errorId}
                role="alert"
                className="text-sm text-error-600 dark:text-error-500"
              >
                {error}
              </p>
            )}

            {/* Helper text (hidden when error is shown) */}
            {!hasError && helperText && (
              <p
                id={helperId}
                className="text-sm text-gray-500 dark:text-gray-400"
              >
                {helperText}
              </p>
            )}
          </div>

          {/* Character count */}
          {showCharCount && (
            <p
              id={counterId}
              className={cn(
                'text-sm flex-shrink-0',
                isOverLimit
                  ? 'text-error-600 dark:text-error-500'
                  : 'text-gray-500 dark:text-gray-400'
              )}
              aria-live="polite"
            >
              {currentLength}
              {maxCharCount !== undefined && ` / ${maxCharCount}`}
            </p>
          )}
        </div>
      </div>
    );
  }
);

Textarea.displayName = 'Textarea';