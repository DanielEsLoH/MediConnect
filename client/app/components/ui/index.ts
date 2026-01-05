// UI Component Library
// Export all UI components for clean imports: import { Button, Input, Card } from '~/components/ui'

export { Button } from './Button';
export type { ButtonProps, ButtonVariant, ButtonSize } from './Button';

export { Input } from './Input';
export type { InputProps } from './Input';

export {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
} from './Card';
export type {
  CardProps,
  CardPadding,
  CardHeaderProps,
  CardTitleProps,
  CardContentProps,
  CardFooterProps,
} from './Card';

export { Spinner } from './Spinner';
export type { SpinnerProps } from './Spinner';

export { Modal, ModalFooter } from './Modal';
export type { ModalProps, ModalSize, ModalFooterProps } from './Modal';

export { Badge } from './Badge';
export type { BadgeProps, BadgeVariant, BadgeSize } from './Badge';

export { Avatar, AvatarGroup } from './Avatar';
export type {
  AvatarProps,
  AvatarSize,
  AvatarStatus,
  AvatarGroupProps,
} from './Avatar';

export { Pagination } from './Pagination';
export type { PaginationProps } from './Pagination';

export { Select } from './Select';
export type { SelectProps, SelectOption } from './Select';

export { Textarea } from './Textarea';
export type { TextareaProps } from './Textarea';

export { Tabs, useTabState } from './Tabs';
export type { TabsProps, Tab } from './Tabs';