import { useState, useMemo, useCallback } from "react";
import { useSearchParams } from "react-router";

/**
 * Configuration options for usePagination hook
 */
export interface UsePaginationOptions {
  /** Total number of items to paginate */
  totalItems: number;
  /** Initial page number (1-indexed, default: 1) */
  initialPage?: number;
  /** Initial number of items per page (default: 10) */
  initialPageSize?: number;
  /** Available page size options (default: [10, 25, 50, 100]) */
  pageSizeOptions?: number[];
  /** Whether to sync pagination state with URL search params */
  syncWithUrl?: boolean;
  /** URL param name for page (default: 'page') */
  pageParamName?: string;
  /** URL param name for page size (default: 'pageSize') */
  pageSizeParamName?: string;
}

/**
 * Return type for usePagination hook
 */
export interface UsePaginationReturn {
  /** Current page number (1-indexed) */
  page: number;
  /** Set the current page */
  setPage: (page: number) => void;
  /** Current page size (items per page) */
  pageSize: number;
  /** Set the page size (resets to page 1) */
  setPageSize: (size: number) => void;
  /** Total number of pages */
  totalPages: number;
  /** Offset for slicing data (0-indexed) */
  offset: number;
  /** Whether there is a next page */
  hasNextPage: boolean;
  /** Whether there is a previous page */
  hasPrevPage: boolean;
  /** Go to next page */
  nextPage: () => void;
  /** Go to previous page */
  prevPage: () => void;
  /** Go to first page */
  firstPage: () => void;
  /** Go to last page */
  lastPage: () => void;
  /** Current page range showing items X to Y */
  pageRange: { start: number; end: number };
  /** Available page size options */
  pageSizeOptions: number[];
  /** Total number of items */
  totalItems: number;
  /** Reset pagination to initial state */
  reset: () => void;
}

/**
 * Custom hook for managing pagination state.
 *
 * Features:
 * - 1-indexed page numbers (user-friendly)
 * - Automatic total pages calculation
 * - Navigation helpers (next, prev, first, last)
 * - Page size management with auto-reset to page 1
 * - Offset calculation for data slicing
 * - Page range display (showing items X to Y of Z)
 * - Optional URL sync for bookmarkable pagination
 *
 * @param options - Pagination configuration options
 * @returns Pagination state and controls
 *
 * @example
 * // Basic usage
 * function UserList({ users }: { users: User[] }) {
 *   const {
 *     page,
 *     setPage,
 *     pageSize,
 *     offset,
 *     totalPages,
 *     hasNextPage,
 *     hasPrevPage,
 *     nextPage,
 *     prevPage,
 *     pageRange
 *   } = usePagination({ totalItems: users.length });
 *
 *   const paginatedUsers = users.slice(offset, offset + pageSize);
 *
 *   return (
 *     <div>
 *       <ul>
 *         {paginatedUsers.map(user => <UserRow key={user.id} user={user} />)}
 *       </ul>
 *       <div>
 *         Showing {pageRange.start} to {pageRange.end} of {users.length}
 *       </div>
 *       <div>
 *         <button onClick={prevPage} disabled={!hasPrevPage}>Previous</button>
 *         <span>Page {page} of {totalPages}</span>
 *         <button onClick={nextPage} disabled={!hasNextPage}>Next</button>
 *       </div>
 *     </div>
 *   );
 * }
 *
 * @example
 * // With URL sync
 * function SearchResults() {
 *   const { page, setPage, pageSize, setPageSize, offset } = usePagination({
 *     totalItems: 500,
 *     syncWithUrl: true,
 *     initialPageSize: 25
 *   });
 *
 *   // URL will update to ?page=2&pageSize=25 when navigating
 * }
 *
 * @example
 * // Server-side pagination
 * function ApiDataTable() {
 *   const [data, setData] = useState({ items: [], total: 0 });
 *   const { page, pageSize, offset } = usePagination({
 *     totalItems: data.total,
 *     syncWithUrl: true
 *   });
 *
 *   useEffect(() => {
 *     fetchData({ page, pageSize }).then(setData);
 *   }, [page, pageSize]);
 *
 *   return <Table data={data.items} />;
 * }
 */
export function usePagination(options: UsePaginationOptions): UsePaginationReturn {
  const {
    totalItems,
    initialPage = 1,
    initialPageSize = 10,
    pageSizeOptions = [10, 25, 50, 100],
    syncWithUrl = false,
    pageParamName = "page",
    pageSizeParamName = "pageSize",
  } = options;

  // URL search params for syncing (only used if syncWithUrl is true)
  const [searchParams, setSearchParams] = useSearchParams();

  // Get initial values from URL if syncing
  const getInitialPage = (): number => {
    if (syncWithUrl) {
      const urlPage = searchParams.get(pageParamName);
      if (urlPage) {
        const parsed = parseInt(urlPage, 10);
        if (!isNaN(parsed) && parsed > 0) {
          return parsed;
        }
      }
    }
    return initialPage;
  };

  const getInitialPageSize = (): number => {
    if (syncWithUrl) {
      const urlPageSize = searchParams.get(pageSizeParamName);
      if (urlPageSize) {
        const parsed = parseInt(urlPageSize, 10);
        if (!isNaN(parsed) && pageSizeOptions.includes(parsed)) {
          return parsed;
        }
      }
    }
    return initialPageSize;
  };

  const [page, setPageState] = useState<number>(getInitialPage);
  const [pageSize, setPageSizeState] = useState<number>(getInitialPageSize);

  // Calculate total pages
  const totalPages = useMemo(() => {
    return Math.max(1, Math.ceil(totalItems / pageSize));
  }, [totalItems, pageSize]);

  // Calculate offset (0-indexed for array slicing)
  const offset = useMemo(() => {
    return (page - 1) * pageSize;
  }, [page, pageSize]);

  // Calculate page range (1-indexed for display)
  const pageRange = useMemo(() => {
    const start = totalItems === 0 ? 0 : offset + 1;
    const end = Math.min(offset + pageSize, totalItems);
    return { start, end };
  }, [offset, pageSize, totalItems]);

  // Navigation states
  const hasNextPage = page < totalPages;
  const hasPrevPage = page > 1;

  // Update URL params if syncing
  const updateUrl = useCallback(
    (newPage: number, newPageSize: number) => {
      if (!syncWithUrl) return;

      setSearchParams(
        (prev) => {
          const newParams = new URLSearchParams(prev);
          newParams.set(pageParamName, String(newPage));
          newParams.set(pageSizeParamName, String(newPageSize));
          return newParams;
        },
        { replace: true }
      );
    },
    [syncWithUrl, setSearchParams, pageParamName, pageSizeParamName]
  );

  // Set page with bounds checking
  const setPage = useCallback(
    (newPage: number) => {
      const clampedPage = Math.max(1, Math.min(newPage, totalPages));
      setPageState(clampedPage);
      updateUrl(clampedPage, pageSize);
    },
    [totalPages, pageSize, updateUrl]
  );

  // Set page size and reset to page 1
  const setPageSize = useCallback(
    (newSize: number) => {
      if (!pageSizeOptions.includes(newSize)) {
        console.warn(
          `[usePagination] Page size ${newSize} is not in pageSizeOptions`
        );
        return;
      }
      setPageSizeState(newSize);
      setPageState(1); // Reset to first page when page size changes
      updateUrl(1, newSize);
    },
    [pageSizeOptions, updateUrl]
  );

  // Navigation helpers
  const nextPage = useCallback(() => {
    if (hasNextPage) {
      setPage(page + 1);
    }
  }, [hasNextPage, page, setPage]);

  const prevPage = useCallback(() => {
    if (hasPrevPage) {
      setPage(page - 1);
    }
  }, [hasPrevPage, page, setPage]);

  const firstPage = useCallback(() => {
    setPage(1);
  }, [setPage]);

  const lastPage = useCallback(() => {
    setPage(totalPages);
  }, [setPage, totalPages]);

  // Reset to initial state
  const reset = useCallback(() => {
    setPageState(initialPage);
    setPageSizeState(initialPageSize);
    updateUrl(initialPage, initialPageSize);
  }, [initialPage, initialPageSize, updateUrl]);

  // Adjust page if it's beyond total pages (e.g., after filtering reduces items)
  useMemo(() => {
    if (page > totalPages && totalPages > 0) {
      setPageState(totalPages);
      updateUrl(totalPages, pageSize);
    }
  }, [page, totalPages, pageSize, updateUrl]);

  return {
    page,
    setPage,
    pageSize,
    setPageSize,
    totalPages,
    offset,
    hasNextPage,
    hasPrevPage,
    nextPage,
    prevPage,
    firstPage,
    lastPage,
    pageRange,
    pageSizeOptions,
    totalItems,
    reset,
  };
}

/**
 * Generate an array of page numbers for pagination UI
 * Useful for rendering page number buttons with ellipsis
 *
 * @param currentPage - Current page number
 * @param totalPages - Total number of pages
 * @param siblingCount - Number of pages to show on each side of current (default: 1)
 * @returns Array of page numbers and 'ellipsis' markers
 *
 * @example
 * const pages = getPageNumbers(5, 10, 1);
 * // Returns: [1, 'ellipsis', 4, 5, 6, 'ellipsis', 10]
 *
 * @example
 * function PaginationButtons() {
 *   const { page, setPage, totalPages } = usePagination({ totalItems: 200 });
 *   const pages = getPageNumbers(page, totalPages);
 *
 *   return (
 *     <div>
 *       {pages.map((p, i) =>
 *         p === 'ellipsis' ? (
 *           <span key={i}>...</span>
 *         ) : (
 *           <button key={i} onClick={() => setPage(p)} disabled={p === page}>
 *             {p}
 *           </button>
 *         )
 *       )}
 *     </div>
 *   );
 * }
 */
export function getPageNumbers(
  currentPage: number,
  totalPages: number,
  siblingCount: number = 1
): (number | "ellipsis")[] {
  const totalPageNumbers = siblingCount * 2 + 5; // siblings + first + last + current + 2 ellipsis

  // If total pages is less than what we'd show, just return all pages
  if (totalPages <= totalPageNumbers) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }

  const leftSiblingIndex = Math.max(currentPage - siblingCount, 1);
  const rightSiblingIndex = Math.min(currentPage + siblingCount, totalPages);

  const shouldShowLeftEllipsis = leftSiblingIndex > 2;
  const shouldShowRightEllipsis = rightSiblingIndex < totalPages - 1;

  if (!shouldShowLeftEllipsis && shouldShowRightEllipsis) {
    // Show left side pages + right ellipsis + last page
    const leftItemCount = 3 + 2 * siblingCount;
    const leftRange = Array.from({ length: leftItemCount }, (_, i) => i + 1);
    return [...leftRange, "ellipsis", totalPages];
  }

  if (shouldShowLeftEllipsis && !shouldShowRightEllipsis) {
    // Show first page + left ellipsis + right side pages
    const rightItemCount = 3 + 2 * siblingCount;
    const rightRange = Array.from(
      { length: rightItemCount },
      (_, i) => totalPages - rightItemCount + i + 1
    );
    return [1, "ellipsis", ...rightRange];
  }

  // Show both ellipsis
  const middleRange = Array.from(
    { length: rightSiblingIndex - leftSiblingIndex + 1 },
    (_, i) => leftSiblingIndex + i
  );
  return [1, "ellipsis", ...middleRange, "ellipsis", totalPages];
}