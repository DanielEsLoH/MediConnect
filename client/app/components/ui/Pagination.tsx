import { useCallback, type KeyboardEvent } from 'react';
import { cn } from '~/lib/utils';

export interface PaginationProps {
  /** Current active page (1-indexed) */
  currentPage: number;
  /** Total number of pages */
  totalPages: number;
  /** Callback when page changes */
  onPageChange: (page: number) => void;
  /** Number of page buttons to show on each side of current page */
  siblingCount?: number;
  /** Show compact version (useful for mobile) */
  compact?: boolean;
  /** Additional CSS classes */
  className?: string;
  /** Disabled state */
  disabled?: boolean;
}

/**
 * Generate array of page numbers to display with ellipsis.
 */
function generatePaginationRange(
  currentPage: number,
  totalPages: number,
  siblingCount: number
): (number | 'ellipsis-start' | 'ellipsis-end')[] {
  const totalNumbers = siblingCount * 2 + 5; // siblings + current + 2 boundaries + 2 ellipsis slots

  // If total pages is less than total numbers we want to show, show all
  if (totalPages <= totalNumbers) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }

  const leftSiblingIndex = Math.max(currentPage - siblingCount, 1);
  const rightSiblingIndex = Math.min(currentPage + siblingCount, totalPages);

  const showLeftEllipsis = leftSiblingIndex > 2;
  const showRightEllipsis = rightSiblingIndex < totalPages - 1;

  if (!showLeftEllipsis && showRightEllipsis) {
    const leftItemCount = 3 + 2 * siblingCount;
    const leftRange = Array.from({ length: leftItemCount }, (_, i) => i + 1);
    return [...leftRange, 'ellipsis-end', totalPages];
  }

  if (showLeftEllipsis && !showRightEllipsis) {
    const rightItemCount = 3 + 2 * siblingCount;
    const rightRange = Array.from(
      { length: rightItemCount },
      (_, i) => totalPages - rightItemCount + i + 1
    );
    return [1, 'ellipsis-start', ...rightRange];
  }

  // Both ellipsis
  const middleRange = Array.from(
    { length: rightSiblingIndex - leftSiblingIndex + 1 },
    (_, i) => leftSiblingIndex + i
  );
  return [1, 'ellipsis-start', ...middleRange, 'ellipsis-end', totalPages];
}

/**
 * Accessible Pagination component with keyboard navigation.
 * Displays page numbers with ellipsis for large ranges.
 *
 * @example
 * <Pagination
 *   currentPage={5}
 *   totalPages={20}
 *   onPageChange={(page) => setPage(page)}
 * />
 *
 * @example
 * <Pagination
 *   currentPage={1}
 *   totalPages={10}
 *   onPageChange={handlePageChange}
 *   siblingCount={2}
 *   compact
 * />
 */
export function Pagination({
  currentPage,
  totalPages,
  onPageChange,
  siblingCount = 1,
  compact = false,
  className,
  disabled = false,
}: PaginationProps) {
  const canGoPrevious = currentPage > 1;
  const canGoNext = currentPage < totalPages;

  const handlePrevious = useCallback(() => {
    if (canGoPrevious && !disabled) {
      onPageChange(currentPage - 1);
    }
  }, [canGoPrevious, currentPage, disabled, onPageChange]);

  const handleNext = useCallback(() => {
    if (canGoNext && !disabled) {
      onPageChange(currentPage + 1);
    }
  }, [canGoNext, currentPage, disabled, onPageChange]);

  const handlePageClick = useCallback(
    (page: number) => {
      if (!disabled && page !== currentPage) {
        onPageChange(page);
      }
    },
    [currentPage, disabled, onPageChange]
  );

  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLElement>) => {
      if (disabled) return;

      switch (event.key) {
        case 'ArrowLeft':
          event.preventDefault();
          handlePrevious();
          break;
        case 'ArrowRight':
          event.preventDefault();
          handleNext();
          break;
        case 'Home':
          event.preventDefault();
          onPageChange(1);
          break;
        case 'End':
          event.preventDefault();
          onPageChange(totalPages);
          break;
      }
    },
    [disabled, handleNext, handlePrevious, onPageChange, totalPages]
  );

  const pages = generatePaginationRange(currentPage, totalPages, siblingCount);

  // Base button styles
  const buttonBaseClasses = cn(
    'inline-flex items-center justify-center',
    'min-h-[44px] min-w-[44px] sm:min-h-[36px] sm:min-w-[36px]',
    'rounded-lg border font-medium',
    'transition-colors duration-200',
    'focus:outline-none focus-visible:ring-2',
    'focus-visible:ring-primary-500 focus-visible:ring-offset-2',
    disabled && 'opacity-50 cursor-not-allowed'
  );

  // Compact mode: only show prev/next with page indicator
  if (compact) {
    return (
      <nav
        role="navigation"
        aria-label="Pagination"
        className={cn('flex items-center gap-2', className)}
        onKeyDown={handleKeyDown}
      >
        <button
          type="button"
          onClick={handlePrevious}
          disabled={!canGoPrevious || disabled}
          aria-label="Go to previous page"
          className={cn(
            buttonBaseClasses,
            'border-gray-300 dark:border-gray-700',
            'text-gray-700 dark:text-gray-300',
            'hover:bg-gray-100 dark:hover:bg-gray-800',
            'disabled:hover:bg-transparent dark:disabled:hover:bg-transparent'
          )}
        >
          <ChevronLeftIcon />
        </button>

        <span
          className="text-sm text-gray-600 dark:text-gray-400 min-w-[80px] text-center"
          aria-current="page"
        >
          Page {currentPage} of {totalPages}
        </span>

        <button
          type="button"
          onClick={handleNext}
          disabled={!canGoNext || disabled}
          aria-label="Go to next page"
          className={cn(
            buttonBaseClasses,
            'border-gray-300 dark:border-gray-700',
            'text-gray-700 dark:text-gray-300',
            'hover:bg-gray-100 dark:hover:bg-gray-800',
            'disabled:hover:bg-transparent dark:disabled:hover:bg-transparent'
          )}
        >
          <ChevronRightIcon />
        </button>
      </nav>
    );
  }

  return (
    <nav
      role="navigation"
      aria-label="Pagination"
      className={cn('flex items-center gap-1', className)}
      onKeyDown={handleKeyDown}
    >
      {/* Previous button */}
      <button
        type="button"
        onClick={handlePrevious}
        disabled={!canGoPrevious || disabled}
        aria-label="Go to previous page"
        className={cn(
          buttonBaseClasses,
          'border-gray-300 dark:border-gray-700',
          'text-gray-700 dark:text-gray-300',
          'hover:bg-gray-100 dark:hover:bg-gray-800',
          'disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          'mr-1'
        )}
      >
        <ChevronLeftIcon />
        <span className="hidden sm:inline ml-1">Previous</span>
      </button>

      {/* Page numbers */}
      <div className="hidden sm:flex items-center gap-1">
        {pages.map((page, index) => {
          if (page === 'ellipsis-start' || page === 'ellipsis-end') {
            return (
              <span
                key={page}
                className="px-2 text-gray-500 dark:text-gray-400"
                aria-hidden="true"
              >
                ...
              </span>
            );
          }

          const isActive = page === currentPage;
          return (
            <button
              key={page}
              type="button"
              onClick={() => handlePageClick(page)}
              disabled={disabled}
              aria-label={`Go to page ${page}`}
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                buttonBaseClasses,
                isActive
                  ? [
                      'bg-primary-600 border-primary-600 text-white',
                      'hover:bg-primary-700 hover:border-primary-700',
                      'dark:bg-primary-500 dark:border-primary-500',
                    ]
                  : [
                      'border-gray-300 dark:border-gray-700',
                      'text-gray-700 dark:text-gray-300',
                      'hover:bg-gray-100 dark:hover:bg-gray-800',
                    ]
              )}
            >
              {page}
            </button>
          );
        })}
      </div>

      {/* Mobile page indicator */}
      <span
        className="sm:hidden text-sm text-gray-600 dark:text-gray-400 min-w-[60px] text-center"
        aria-current="page"
      >
        {currentPage} / {totalPages}
      </span>

      {/* Next button */}
      <button
        type="button"
        onClick={handleNext}
        disabled={!canGoNext || disabled}
        aria-label="Go to next page"
        className={cn(
          buttonBaseClasses,
          'border-gray-300 dark:border-gray-700',
          'text-gray-700 dark:text-gray-300',
          'hover:bg-gray-100 dark:hover:bg-gray-800',
          'disabled:hover:bg-transparent dark:disabled:hover:bg-transparent',
          'ml-1'
        )}
      >
        <span className="hidden sm:inline mr-1">Next</span>
        <ChevronRightIcon />
      </button>
    </nav>
  );
}

// Icon components
function ChevronLeftIcon() {
  return (
    <svg
      className="w-5 h-5"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
      aria-hidden="true"
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
    </svg>
  );
}

function ChevronRightIcon() {
  return (
    <svg
      className="w-5 h-5"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2}
      aria-hidden="true"
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
    </svg>
  );
}