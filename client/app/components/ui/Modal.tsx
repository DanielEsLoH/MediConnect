import {
  useEffect,
  useRef,
  useCallback,
  type ReactNode,
  type KeyboardEvent,
} from 'react';
import { createPortal } from 'react-dom';
import { cn } from '~/lib/utils';

export type ModalSize = 'sm' | 'md' | 'lg' | 'xl' | 'full';

export interface ModalProps {
  /** Whether the modal is open */
  isOpen: boolean;
  /** Callback when modal should close */
  onClose: () => void;
  /** Modal title displayed in the header */
  title?: string;
  /** Modal content */
  children: ReactNode;
  /** Size variant of the modal */
  size?: ModalSize;
  /** Whether clicking the backdrop closes the modal */
  closeOnBackdropClick?: boolean;
  /** Whether pressing Escape closes the modal */
  closeOnEscape?: boolean;
  /** Additional class for the modal container */
  className?: string;
  /** ID for aria-describedby linking */
  descriptionId?: string;
}

const sizeClasses: Record<ModalSize, string> = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-xl',
  full: 'max-w-[calc(100vw-2rem)] sm:max-w-[calc(100vw-4rem)] h-[calc(100vh-2rem)] sm:h-[calc(100vh-4rem)]',
};

/**
 * Accessible Modal/Dialog component with focus trap, animations, and portal rendering.
 * Follows WAI-ARIA dialog pattern with proper keyboard navigation.
 *
 * @example
 * <Modal isOpen={isOpen} onClose={() => setIsOpen(false)} title="Confirm Action">
 *   <p>Are you sure you want to proceed?</p>
 * </Modal>
 *
 * @example
 * <Modal isOpen={isOpen} onClose={close} size="lg" closeOnBackdropClick={false}>
 *   <form>...</form>
 * </Modal>
 */
export function Modal({
  isOpen,
  onClose,
  title,
  children,
  size = 'md',
  closeOnBackdropClick = true,
  closeOnEscape = true,
  className,
  descriptionId,
}: ModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousActiveElement = useRef<Element | null>(null);
  const titleId = title ? `modal-title-${title.replace(/\s+/g, '-').toLowerCase()}` : undefined;

  // Handle escape key
  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      if (event.key === 'Escape' && closeOnEscape) {
        event.preventDefault();
        onClose();
      }

      // Focus trap - Tab navigation
      if (event.key === 'Tab' && modalRef.current) {
        const focusableElements = modalRef.current.querySelectorAll<HTMLElement>(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );
        const firstElement = focusableElements[0];
        const lastElement = focusableElements[focusableElements.length - 1];

        if (event.shiftKey && document.activeElement === firstElement) {
          event.preventDefault();
          lastElement?.focus();
        } else if (!event.shiftKey && document.activeElement === lastElement) {
          event.preventDefault();
          firstElement?.focus();
        }
      }
    },
    [closeOnEscape, onClose]
  );

  // Handle backdrop click
  const handleBackdropClick = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) => {
      if (closeOnBackdropClick && event.target === event.currentTarget) {
        onClose();
      }
    },
    [closeOnBackdropClick, onClose]
  );

  // Focus management and body scroll lock
  useEffect(() => {
    if (isOpen) {
      // Store currently focused element
      previousActiveElement.current = document.activeElement;

      // Lock body scroll
      document.body.style.overflow = 'hidden';

      // Focus the modal
      const timer = setTimeout(() => {
        modalRef.current?.focus();
      }, 0);

      return () => {
        clearTimeout(timer);
        document.body.style.overflow = '';
        // Restore focus to previous element
        if (previousActiveElement.current instanceof HTMLElement) {
          previousActiveElement.current.focus();
        }
      };
    }
  }, [isOpen]);

  // Don't render if not open
  if (!isOpen) return null;

  // Render to portal
  return createPortal(
    <div
      className={cn(
        // Backdrop
        'fixed inset-0 z-50',
        'bg-black/50 backdrop-blur-sm',
        // Animation
        'animate-in fade-in duration-200',
        // Flex centering
        'flex items-center justify-center',
        'p-4'
      )}
      onClick={handleBackdropClick}
      aria-hidden="true"
    >
      <div
        ref={modalRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={descriptionId}
        tabIndex={-1}
        onKeyDown={handleKeyDown}
        className={cn(
          // Base styles
          'relative w-full bg-white rounded-xl shadow-xl',
          'border border-gray-200',
          // Size
          sizeClasses[size],
          // Animation
          'animate-in zoom-in-95 slide-in-from-bottom-4 duration-200',
          // Focus outline (for accessibility indicators)
          'focus:outline-none',
          // Dark mode
          'dark:bg-gray-900 dark:border-gray-700',
          // Full size variant needs flex column
          size === 'full' && 'flex flex-col',
          className
        )}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        {title && (
          <div
            className={cn(
              'flex items-center justify-between',
              'px-4 py-3 sm:px-6 sm:py-4',
              'border-b border-gray-200 dark:border-gray-700'
            )}
          >
            <h2
              id={titleId}
              className="text-lg font-semibold text-gray-900 dark:text-gray-100"
            >
              {title}
            </h2>
            <button
              type="button"
              onClick={onClose}
              className={cn(
                'p-2 -mr-2 rounded-lg',
                'text-gray-500 hover:text-gray-700',
                'hover:bg-gray-100 dark:hover:bg-gray-800',
                'focus:outline-none focus-visible:ring-2',
                'focus-visible:ring-primary-500 focus-visible:ring-offset-2',
                'transition-colors duration-200',
                'dark:text-gray-400 dark:hover:text-gray-200'
              )}
              aria-label="Close modal"
            >
              <svg
                className="w-5 h-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        )}

        {/* Content */}
        <div
          className={cn(
            'px-4 py-4 sm:px-6 sm:py-5',
            size === 'full' && 'flex-1 overflow-y-auto'
          )}
        >
          {children}
        </div>

        {/* Close button when no title */}
        {!title && (
          <button
            type="button"
            onClick={onClose}
            className={cn(
              'absolute top-3 right-3',
              'p-2 rounded-lg',
              'text-gray-500 hover:text-gray-700',
              'hover:bg-gray-100 dark:hover:bg-gray-800',
              'focus:outline-none focus-visible:ring-2',
              'focus-visible:ring-primary-500 focus-visible:ring-offset-2',
              'transition-colors duration-200',
              'dark:text-gray-400 dark:hover:text-gray-200'
            )}
            aria-label="Close modal"
          >
            <svg
              className="w-5 h-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
              aria-hidden="true"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        )}
      </div>
    </div>,
    document.body
  );
}

/**
 * Modal Footer component for action buttons.
 */
export interface ModalFooterProps {
  children: ReactNode;
  className?: string;
}

export function ModalFooter({ children, className }: ModalFooterProps) {
  return (
    <div
      className={cn(
        'flex flex-col-reverse sm:flex-row sm:justify-end gap-2 sm:gap-3',
        'px-4 py-3 sm:px-6 sm:py-4',
        'border-t border-gray-200 dark:border-gray-700',
        'bg-gray-50 dark:bg-gray-800/50',
        'rounded-b-xl',
        className
      )}
    >
      {children}
    </div>
  );
}