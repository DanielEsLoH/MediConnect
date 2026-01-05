import { useState, useEffect } from "react";

/**
 * Custom hook that debounces a value.
 * Returns the debounced value after the specified delay has passed
 * without the value changing.
 *
 * Useful for optimizing search inputs, API calls, or any scenario
 * where you want to delay processing until user input has settled.
 *
 * @template T - The type of value being debounced
 * @param value - The value to debounce
 * @param delay - The delay in milliseconds (default: 300ms)
 * @returns The debounced value
 *
 * @example
 * function SearchComponent() {
 *   const [searchTerm, setSearchTerm] = useState('');
 *   const debouncedSearchTerm = useDebounce(searchTerm, 300);
 *
 *   useEffect(() => {
 *     if (debouncedSearchTerm) {
 *       // API call won't fire until user stops typing for 300ms
 *       searchApi(debouncedSearchTerm);
 *     }
 *   }, [debouncedSearchTerm]);
 *
 *   return (
 *     <input
 *       value={searchTerm}
 *       onChange={(e) => setSearchTerm(e.target.value)}
 *       placeholder="Search..."
 *     />
 *   );
 * }
 *
 * @example
 * // Debouncing an object
 * const [filters, setFilters] = useState({ category: '', price: 0 });
 * const debouncedFilters = useDebounce(filters, 500);
 */
export function useDebounce<T>(value: T, delay: number = 300): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    // Set up the timeout to update debounced value
    const timeoutId = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    // Clean up the timeout if value or delay changes
    // This prevents the debounced value from updating if value changes within delay
    return () => {
      clearTimeout(timeoutId);
    };
  }, [value, delay]);

  return debouncedValue;
}

/**
 * Custom hook that provides both the debounced value and a way to flush it immediately.
 * Useful when you need manual control over when to apply the debounced value.
 *
 * @template T - The type of value being debounced
 * @param value - The value to debounce
 * @param delay - The delay in milliseconds (default: 300ms)
 * @returns Tuple of [debouncedValue, flushValue]
 *
 * @example
 * function SearchWithSubmit() {
 *   const [searchTerm, setSearchTerm] = useState('');
 *   const [debouncedTerm, flush] = useDebounceWithFlush(searchTerm, 500);
 *
 *   const handleSubmit = () => {
 *     flush(); // Immediately apply the current value
 *   };
 *
 *   return (
 *     <form onSubmit={handleSubmit}>
 *       <input value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} />
 *       <button type="submit">Search Now</button>
 *     </form>
 *   );
 * }
 */
export function useDebounceWithFlush<T>(
  value: T,
  delay: number = 300
): [T, () => void] {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(timeoutId);
    };
  }, [value, delay]);

  const flush = () => {
    setDebouncedValue(value);
  };

  return [debouncedValue, flush];
}