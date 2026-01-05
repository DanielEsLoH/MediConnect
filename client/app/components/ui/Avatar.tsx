import { useState, useMemo } from 'react';
import { cn } from '~/lib/utils';

export type AvatarSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';
export type AvatarStatus = 'online' | 'offline' | 'busy' | 'away';

export interface AvatarProps {
  /** Image source URL */
  src?: string;
  /** Alt text for the image (required for accessibility) */
  alt?: string;
  /** User's name - used for initials fallback */
  name?: string;
  /** Size variant */
  size?: AvatarSize;
  /** Status indicator */
  status?: AvatarStatus;
  /** Show border ring */
  ring?: boolean;
  /** Additional CSS classes */
  className?: string;
}

const sizeClasses: Record<AvatarSize, string> = {
  xs: 'w-6 h-6 text-xs',
  sm: 'w-8 h-8 text-sm',
  md: 'w-10 h-10 text-base',
  lg: 'w-12 h-12 text-lg',
  xl: 'w-16 h-16 text-xl',
};

const statusSizeClasses: Record<AvatarSize, string> = {
  xs: 'w-2 h-2 border',
  sm: 'w-2.5 h-2.5 border-[1.5px]',
  md: 'w-3 h-3 border-2',
  lg: 'w-3.5 h-3.5 border-2',
  xl: 'w-4 h-4 border-2',
};

const statusPositionClasses: Record<AvatarSize, string> = {
  xs: 'bottom-0 right-0',
  sm: 'bottom-0 right-0',
  md: 'bottom-0 right-0',
  lg: 'bottom-0.5 right-0.5',
  xl: 'bottom-1 right-1',
};

const statusColorClasses: Record<AvatarStatus, string> = {
  online: 'bg-success-500',
  offline: 'bg-gray-400',
  busy: 'bg-error-500',
  away: 'bg-warning-500',
};

// Background colors for initials - deterministic based on name
const initialsColors = [
  'bg-primary-500',
  'bg-secondary-500',
  'bg-success-500',
  'bg-warning-500',
  'bg-info-500',
  'bg-purple-500',
  'bg-pink-500',
  'bg-indigo-500',
  'bg-teal-500',
  'bg-orange-500',
];

/**
 * Extract initials from a name string.
 * Takes first letter of first name and first letter of last name.
 */
function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 0) return '';
  if (parts.length === 1) {
    return parts[0].charAt(0).toUpperCase();
  }
  return (
    parts[0].charAt(0).toUpperCase() +
    parts[parts.length - 1].charAt(0).toUpperCase()
  );
}

/**
 * Get a deterministic color based on the name string.
 */
function getColorForName(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  const index = Math.abs(hash) % initialsColors.length;
  return initialsColors[index];
}

/**
 * Avatar component for displaying user profile images or initials.
 * Automatically falls back to initials when no image is provided or image fails to load.
 *
 * @example
 * <Avatar src="/user.jpg" alt="John Doe" size="md" />
 * <Avatar name="John Doe" size="lg" status="online" />
 * <Avatar name="Jane Smith" ring />
 */
export function Avatar({
  src,
  alt,
  name,
  size = 'md',
  status,
  ring = false,
  className,
}: AvatarProps) {
  const [imageError, setImageError] = useState(false);

  const initials = useMemo(() => (name ? getInitials(name) : ''), [name]);
  const bgColor = useMemo(
    () => (name ? getColorForName(name) : 'bg-gray-400'),
    [name]
  );

  const showImage = src && !imageError;
  const showInitials = !showImage && initials;
  const showPlaceholder = !showImage && !showInitials;

  return (
    <div className={cn('relative inline-block', className)}>
      <div
        className={cn(
          // Base styles
          'relative flex items-center justify-center',
          'rounded-full overflow-hidden',
          'font-medium text-white',
          // Size
          sizeClasses[size],
          // Ring
          ring && [
            'ring-2 ring-white',
            'dark:ring-gray-900',
          ],
          // Background for non-image states
          !showImage && bgColor,
          // Placeholder background
          showPlaceholder && 'bg-gray-400'
        )}
      >
        {/* Image */}
        {showImage && (
          <img
            src={src}
            alt={alt || name || 'Avatar'}
            className="w-full h-full object-cover"
            onError={() => setImageError(true)}
          />
        )}

        {/* Initials */}
        {showInitials && (
          <span aria-hidden="true">{initials}</span>
        )}

        {/* Placeholder icon */}
        {showPlaceholder && (
          <svg
            className="w-1/2 h-1/2 text-white"
            fill="currentColor"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
          </svg>
        )}
      </div>

      {/* Status indicator */}
      {status && (
        <span
          className={cn(
            'absolute rounded-full',
            'border-white dark:border-gray-900',
            statusSizeClasses[size],
            statusPositionClasses[size],
            statusColorClasses[status]
          )}
          aria-label={`Status: ${status}`}
        />
      )}

      {/* Screen reader text */}
      <span className="sr-only">
        {alt || name || 'User avatar'}
        {status && ` - ${status}`}
      </span>
    </div>
  );
}

/**
 * Avatar Group component for displaying multiple avatars overlapping.
 */
export interface AvatarGroupProps {
  /** Array of avatar props */
  avatars: Omit<AvatarProps, 'ring'>[];
  /** Maximum number of avatars to display */
  max?: number;
  /** Size for all avatars */
  size?: AvatarSize;
  /** Additional CSS classes */
  className?: string;
}

export function AvatarGroup({
  avatars,
  max = 4,
  size = 'md',
  className,
}: AvatarGroupProps) {
  const visibleAvatars = avatars.slice(0, max);
  const remainingCount = avatars.length - max;

  const overlapClasses: Record<AvatarSize, string> = {
    xs: '-ml-1.5',
    sm: '-ml-2',
    md: '-ml-2.5',
    lg: '-ml-3',
    xl: '-ml-4',
  };

  return (
    <div className={cn('flex items-center', className)}>
      {visibleAvatars.map((avatar, index) => (
        <div
          key={avatar.src || avatar.name || index}
          className={cn(index > 0 && overlapClasses[size])}
        >
          <Avatar {...avatar} size={size} ring />
        </div>
      ))}

      {/* Remaining count indicator */}
      {remainingCount > 0 && (
        <div
          className={cn(
            overlapClasses[size],
            'flex items-center justify-center',
            'rounded-full bg-gray-200 dark:bg-gray-700',
            'text-gray-600 dark:text-gray-300',
            'font-medium ring-2 ring-white dark:ring-gray-900',
            sizeClasses[size]
          )}
        >
          <span className="text-[0.65em]">+{remainingCount}</span>
        </div>
      )}
    </div>
  );
}