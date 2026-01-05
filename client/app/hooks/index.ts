/**
 * Custom React Hooks for MediConnect
 *
 * This barrel file exports all custom hooks for clean imports.
 *
 * @example
 * // Import individual hooks
 * import { useDebounce, useLocalStorage, useMediaQuery } from '~/hooks';
 *
 * @example
 * // Import specific hooks from their files for tree-shaking
 * import { useDebounce } from '~/hooks/useDebounce';
 */

// Debounce hook for search optimization
export { useDebounce, useDebounceWithFlush } from "./useDebounce";

// LocalStorage hook for persistent state
export { useLocalStorage, useLocalStorageRemove } from "./useLocalStorage";

// Media query hooks for responsive design
export {
  useMediaQuery,
  useIsMobile,
  useIsTablet,
  useIsDesktop,
  usePreferredColorScheme,
  usePrefersReducedMotion,
  useBreakpoints,
} from "./useMediaQuery";

// Pagination hook for list management
export {
  usePagination,
  getPageNumbers,
  type UsePaginationOptions,
  type UsePaginationReturn,
} from "./usePagination";

// Async effect hooks for safe async operations
export {
  useAsyncEffect,
  useAsyncEffectWithCleanup,
  useAbortSignal,
} from "./useAsyncEffect";

// Intersection Observer hooks for visibility detection
export {
  useOnScreen,
  useOnScreenOnce,
  useOnScreenRatio,
  useMultipleOnScreen,
} from "./useOnScreen";

// Click outside detection for modals/dropdowns
export { useClickOutside } from "./useClickOutside";

// WebSocket connection for real-time updates
export { useWebSocket } from "./useWebSocket";