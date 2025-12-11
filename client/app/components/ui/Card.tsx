import type { ComponentPropsWithoutRef, ReactNode } from 'react';
import { cn } from '~/lib/utils';

export type CardPadding = 'none' | 'sm' | 'md' | 'lg';

export interface CardProps extends ComponentPropsWithoutRef<'div'> {
  /** Content inside the card */
  children: ReactNode;
  /** Padding size - responsive by default (smaller on mobile, larger on desktop) */
  padding?: CardPadding;
  /** Enable hover effect with subtle elevation */
  hover?: boolean;
  /** Make the card clickable (adds focus styles) */
  clickable?: boolean;
}

// Responsive padding: smaller on mobile, larger on desktop
const paddingClasses: Record<CardPadding, string> = {
  none: 'p-0',
  sm: 'p-3 sm:p-4',
  md: 'p-4 sm:p-5 md:p-6',
  lg: 'p-5 sm:p-6 md:p-8',
};

/**
 * Responsive Card component with subtle shadow and rounded corners.
 * Responsive padding that adjusts based on screen size.
 *
 * @example
 * <Card>Basic card content</Card>
 * <Card padding="lg" hover>Hover effect card</Card>
 * <Card padding="sm" clickable onClick={handleClick}>Clickable card</Card>
 */
export function Card({
  children,
  className,
  padding = 'md',
  hover = false,
  clickable = false,
  ...props
}: CardProps) {
  return (
    <div
      role={clickable ? 'button' : undefined}
      tabIndex={clickable ? 0 : undefined}
      className={cn(
        // Base styles
        'rounded-xl border bg-white',
        'border-gray-200 shadow-sm',
        // Padding
        paddingClasses[padding],
        // Hover effect
        hover && [
          'transition-all duration-200',
          'hover:shadow-md hover:border-gray-300',
          'hover:-translate-y-0.5',
        ],
        // Clickable styles
        clickable && [
          'cursor-pointer transition-all duration-200',
          'hover:shadow-md hover:border-gray-300',
          'focus:outline-none focus-visible:ring-2',
          'focus-visible:ring-primary-500 focus-visible:ring-offset-2',
          'active:scale-[0.99]',
        ],
        // Dark mode
        'dark:bg-gray-900 dark:border-gray-800',
        'dark:hover:border-gray-700',
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}

/**
 * Card Header component for consistent card title styling.
 */
export interface CardHeaderProps {
  children: ReactNode;
  className?: string;
}

export function CardHeader({ children, className }: CardHeaderProps) {
  return (
    <div
      className={cn(
        'mb-3 sm:mb-4',
        'pb-3 sm:pb-4',
        'border-b border-gray-200 dark:border-gray-700',
        className
      )}
    >
      {children}
    </div>
  );
}

/**
 * Card Title component for semantic heading within cards.
 */
export interface CardTitleProps {
  children: ReactNode;
  className?: string;
  as?: 'h1' | 'h2' | 'h3' | 'h4' | 'h5' | 'h6';
}

export function CardTitle({
  children,
  className,
  as: Component = 'h3',
}: CardTitleProps) {
  return (
    <Component
      className={cn(
        'text-lg sm:text-xl font-semibold',
        'text-gray-900 dark:text-gray-100',
        className
      )}
    >
      {children}
    </Component>
  );
}

/**
 * Card Content component for the main body of the card.
 */
export interface CardContentProps {
  children: ReactNode;
  className?: string;
}

export function CardContent({ children, className }: CardContentProps) {
  return (
    <div className={cn('text-gray-600 dark:text-gray-400', className)}>
      {children}
    </div>
  );
}

/**
 * Card Footer component for actions or additional info.
 */
export interface CardFooterProps {
  children: ReactNode;
  className?: string;
}

export function CardFooter({ children, className }: CardFooterProps) {
  return (
    <div
      className={cn(
        'mt-3 sm:mt-4',
        'pt-3 sm:pt-4',
        'border-t border-gray-200 dark:border-gray-700',
        className
      )}
    >
      {children}
    </div>
  );
}
