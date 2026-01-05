import {
  useState,
  useRef,
  useEffect,
  useCallback,
  useId,
  type KeyboardEvent,
} from 'react';
import { cn } from '~/lib/utils';
import { Spinner } from './Spinner';

export interface SelectOption {
  /** Option value */
  value: string;
  /** Display label */
  label: string;
  /** Whether the option is disabled */
  disabled?: boolean;
}

export interface SelectProps {
  /** Array of options to display */
  options: SelectOption[];
  /** Currently selected value */
  value?: string;
  /** Callback when selection changes */
  onChange?: (value: string) => void;
  /** Placeholder text when no value selected */
  placeholder?: string;
  /** Label displayed above the select */
  label?: string;
  /** Error message to display */
  error?: string;
  /** Helper text displayed below the select */
  helperText?: string;
  /** Whether the select is disabled */
  disabled?: boolean;
  /** Whether the select is loading */
  isLoading?: boolean;
  /** Whether the field is required */
  required?: boolean;
  /** Additional CSS classes for the wrapper */
  wrapperClassName?: string;
  /** Additional CSS classes for the trigger button */
  className?: string;
  /** ID for the select element */
  id?: string;
  /** Name attribute for form submission */
  name?: string;
}

/**
 * Accessible Select/Dropdown component with keyboard navigation.
 * Styled to match the Input component pattern.
 *
 * @example
 * <Select
 *   label="Country"
 *   options={[
 *     { value: 'us', label: 'United States' },
 *     { value: 'ca', label: 'Canada' },
 *   ]}
 *   value={country}
 *   onChange={setCountry}
 * />
 *
 * @example
 * <Select
 *   label="Status"
 *   options={statusOptions}
 *   value={status}
 *   onChange={setStatus}
 *   error="Please select a status"
 * />
 */
export function Select({
  options,
  value,
  onChange,
  placeholder = 'Select an option',
  label,
  error,
  helperText,
  disabled = false,
  isLoading = false,
  required = false,
  wrapperClassName,
  className,
  id,
  name,
}: SelectProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const containerRef = useRef<HTMLDivElement>(null);
  const listboxRef = useRef<HTMLUListElement>(null);

  const generatedId = useId();
  const selectId = id || generatedId;
  const labelId = `${selectId}-label`;
  const errorId = `${selectId}-error`;
  const helperId = `${selectId}-helper`;
  const listboxId = `${selectId}-listbox`;

  const hasError = Boolean(error);
  const isDisabled = disabled || isLoading;
  const selectedOption = options.find((opt) => opt.value === value);

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (
        containerRef.current &&
        !containerRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
  }, [isOpen]);

  // Scroll highlighted option into view
  useEffect(() => {
    if (isOpen && highlightedIndex >= 0 && listboxRef.current) {
      const highlightedElement = listboxRef.current.children[
        highlightedIndex
      ] as HTMLElement;
      highlightedElement?.scrollIntoView({ block: 'nearest' });
    }
  }, [highlightedIndex, isOpen]);

  const handleToggle = useCallback(() => {
    if (!isDisabled) {
      setIsOpen((prev) => !prev);
      if (!isOpen) {
        // Set initial highlight to selected option or first option
        const selectedIndex = options.findIndex((opt) => opt.value === value);
        setHighlightedIndex(selectedIndex >= 0 ? selectedIndex : 0);
      }
    }
  }, [isDisabled, isOpen, options, value]);

  const handleSelect = useCallback(
    (optionValue: string) => {
      const option = options.find((opt) => opt.value === optionValue);
      if (option && !option.disabled) {
        onChange?.(optionValue);
        setIsOpen(false);
      }
    },
    [onChange, options]
  );

  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLButtonElement>) => {
      if (isDisabled) return;

      switch (event.key) {
        case 'Enter':
        case ' ':
          event.preventDefault();
          if (isOpen && highlightedIndex >= 0) {
            const option = options[highlightedIndex];
            if (option && !option.disabled) {
              handleSelect(option.value);
            }
          } else {
            setIsOpen(true);
          }
          break;

        case 'ArrowDown':
          event.preventDefault();
          if (!isOpen) {
            setIsOpen(true);
          } else {
            setHighlightedIndex((prev) => {
              let next = prev + 1;
              while (next < options.length && options[next].disabled) {
                next++;
              }
              return next < options.length ? next : prev;
            });
          }
          break;

        case 'ArrowUp':
          event.preventDefault();
          if (!isOpen) {
            setIsOpen(true);
          } else {
            setHighlightedIndex((prev) => {
              let next = prev - 1;
              while (next >= 0 && options[next].disabled) {
                next--;
              }
              return next >= 0 ? next : prev;
            });
          }
          break;

        case 'Home':
          event.preventDefault();
          if (isOpen) {
            const firstEnabled = options.findIndex((opt) => !opt.disabled);
            if (firstEnabled >= 0) setHighlightedIndex(firstEnabled);
          }
          break;

        case 'End':
          event.preventDefault();
          if (isOpen) {
            // Find last enabled option (ES5 compatible)
            let lastEnabled = -1;
            for (let i = options.length - 1; i >= 0; i--) {
              if (!options[i].disabled) {
                lastEnabled = i;
                break;
              }
            }
            if (lastEnabled >= 0) setHighlightedIndex(lastEnabled);
          }
          break;

        case 'Escape':
          event.preventDefault();
          setIsOpen(false);
          break;

        case 'Tab':
          setIsOpen(false);
          break;
      }
    },
    [handleSelect, highlightedIndex, isDisabled, isOpen, options]
  );

  return (
    <div ref={containerRef} className={cn('w-full relative', wrapperClassName)}>
      {/* Label */}
      {label && (
        <label
          id={labelId}
          className={cn(
            'block text-sm font-medium mb-1.5',
            'text-gray-700 dark:text-gray-300',
            hasError && 'text-error-600 dark:text-error-500',
            isDisabled && 'opacity-60'
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

      {/* Hidden native select for form submission */}
      {name && (
        <select
          name={name}
          value={value || ''}
          onChange={() => {}}
          tabIndex={-1}
          className="sr-only"
          aria-hidden="true"
        >
          <option value="">{placeholder}</option>
          {options.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
      )}

      {/* Trigger button */}
      <button
        type="button"
        id={selectId}
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-controls={listboxId}
        aria-labelledby={label ? labelId : undefined}
        aria-invalid={hasError}
        aria-describedby={hasError ? errorId : helperText ? helperId : undefined}
        disabled={isDisabled}
        onClick={handleToggle}
        onKeyDown={handleKeyDown}
        className={cn(
          // Base styles
          'w-full flex items-center justify-between gap-2',
          'rounded-lg border bg-white transition-colors duration-200',
          // Responsive padding
          'px-3 py-3 text-base sm:px-3 sm:py-2.5 sm:text-sm',
          // Min height for touch accessibility
          'min-h-[44px] sm:min-h-[40px]',
          // Text alignment
          'text-left',
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
          isDisabled && 'opacity-60 cursor-not-allowed bg-gray-50',
          // Dark mode
          'dark:bg-gray-900 dark:border-gray-700',
          'dark:hover:border-gray-600',
          !hasError && 'dark:focus:border-primary-400',
          className
        )}
      >
        <span
          className={cn(
            'truncate flex-1',
            selectedOption
              ? 'text-gray-900 dark:text-gray-100'
              : 'text-gray-400 dark:text-gray-500'
          )}
        >
          {selectedOption ? selectedOption.label : placeholder}
        </span>

        {isLoading ? (
          <Spinner size="sm" className="flex-shrink-0" />
        ) : (
          <svg
            className={cn(
              'w-5 h-5 text-gray-400 transition-transform duration-200',
              isOpen && 'rotate-180'
            )}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
            aria-hidden="true"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M19 9l-7 7-7-7"
            />
          </svg>
        )}
      </button>

      {/* Dropdown listbox */}
      {isOpen && (
        <ul
          id={listboxId}
          ref={listboxRef}
          role="listbox"
          aria-labelledby={label ? labelId : undefined}
          className={cn(
            'absolute z-50 w-full mt-1',
            'max-h-60 overflow-auto',
            'bg-white border border-gray-200 rounded-lg shadow-lg',
            'py-1',
            'dark:bg-gray-900 dark:border-gray-700',
            // Animation
            'animate-in fade-in slide-in-from-top-2 duration-150'
          )}
        >
          {options.map((option, index) => {
            const isSelected = option.value === value;
            const isHighlighted = index === highlightedIndex;

            return (
              <li
                key={option.value}
                role="option"
                aria-selected={isSelected}
                aria-disabled={option.disabled}
                onClick={() => !option.disabled && handleSelect(option.value)}
                onMouseEnter={() => !option.disabled && setHighlightedIndex(index)}
                className={cn(
                  'px-3 py-2.5 sm:py-2 cursor-pointer',
                  'transition-colors duration-100',
                  // Highlighted state
                  isHighlighted && !option.disabled && 'bg-gray-100 dark:bg-gray-800',
                  // Selected state
                  isSelected && [
                    'text-primary-600 dark:text-primary-400',
                    'bg-primary-50 dark:bg-primary-900/20',
                  ],
                  // Default text
                  !isSelected && 'text-gray-900 dark:text-gray-100',
                  // Disabled state
                  option.disabled && [
                    'text-gray-400 dark:text-gray-600',
                    'cursor-not-allowed',
                  ]
                )}
              >
                <div className="flex items-center justify-between">
                  <span className="truncate">{option.label}</span>
                  {isSelected && (
                    <svg
                      className="w-4 h-4 text-primary-600 dark:text-primary-400 flex-shrink-0 ml-2"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2}
                      aria-hidden="true"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                  )}
                </div>
              </li>
            );
          })}

          {options.length === 0 && (
            <li className="px-3 py-2 text-gray-500 dark:text-gray-400 text-center">
              No options available
            </li>
          )}
        </ul>
      )}

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

      {/* Helper text */}
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