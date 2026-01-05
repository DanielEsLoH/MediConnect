import { useState, useEffect, useCallback } from "react";

/**
 * Check if we're in a browser environment (not SSR)
 */
const isBrowser = typeof window !== "undefined";

/**
 * Custom hook that syncs state with localStorage.
 * Provides a useState-like API with automatic persistence.
 *
 * Features:
 * - Type-safe with generics
 * - Handles SSR (checks for window)
 * - JSON serialization/deserialization
 * - Cross-tab synchronization via storage events
 * - Supports function updates like useState
 *
 * @template T - The type of value being stored
 * @param key - The localStorage key
 * @param initialValue - The initial value if no stored value exists
 * @returns Tuple of [storedValue, setValue] similar to useState
 *
 * @example
 * // Simple usage
 * function ThemeToggle() {
 *   const [theme, setTheme] = useLocalStorage('theme', 'light');
 *
 *   return (
 *     <button onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
 *       Current: {theme}
 *     </button>
 *   );
 * }
 *
 * @example
 * // With complex objects
 * interface UserPreferences {
 *   notifications: boolean;
 *   language: string;
 *   fontSize: number;
 * }
 *
 * function Settings() {
 *   const [preferences, setPreferences] = useLocalStorage<UserPreferences>(
 *     'user-preferences',
 *     { notifications: true, language: 'en', fontSize: 16 }
 *   );
 *
 *   const toggleNotifications = () => {
 *     setPreferences(prev => ({
 *       ...prev,
 *       notifications: !prev.notifications
 *     }));
 *   };
 *
 *   return <button onClick={toggleNotifications}>Toggle Notifications</button>;
 * }
 *
 * @example
 * // Storing arrays
 * const [recentSearches, setRecentSearches] = useLocalStorage<string[]>(
 *   'recent-searches',
 *   []
 * );
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((prev: T) => T)) => void] {
  // Get stored value or use initial value
  const readStoredValue = useCallback((): T => {
    if (!isBrowser) {
      return initialValue;
    }

    try {
      const item = window.localStorage.getItem(key);
      if (item === null) {
        return initialValue;
      }
      return JSON.parse(item) as T;
    } catch (error) {
      console.warn(`[useLocalStorage] Error reading key "${key}":`, error);
      return initialValue;
    }
  }, [key, initialValue]);

  // State to store our value
  const [storedValue, setStoredValue] = useState<T>(readStoredValue);

  // Return a wrapped version of useState's setter function that persists to localStorage
  const setValue = useCallback(
    (value: T | ((prev: T) => T)) => {
      try {
        // Allow value to be a function (like useState)
        const valueToStore =
          value instanceof Function ? value(storedValue) : value;

        // Save state
        setStoredValue(valueToStore);

        // Save to localStorage
        if (isBrowser) {
          window.localStorage.setItem(key, JSON.stringify(valueToStore));

          // Dispatch a custom event so other components using this hook can sync
          window.dispatchEvent(
            new CustomEvent("local-storage-change", {
              detail: { key, value: valueToStore },
            })
          );
        }
      } catch (error) {
        console.warn(`[useLocalStorage] Error setting key "${key}":`, error);
      }
    },
    [key, storedValue]
  );

  // Listen for changes from other tabs/windows
  useEffect(() => {
    if (!isBrowser) return;

    const handleStorageChange = (event: StorageEvent) => {
      if (event.key === key && event.newValue !== null) {
        try {
          setStoredValue(JSON.parse(event.newValue) as T);
        } catch (error) {
          console.warn(
            `[useLocalStorage] Error parsing storage event for key "${key}":`,
            error
          );
        }
      } else if (event.key === key && event.newValue === null) {
        // Key was removed
        setStoredValue(initialValue);
      }
    };

    // Listen for changes from the same tab (custom event)
    const handleLocalChange = (event: CustomEvent<{ key: string; value: T }>) => {
      if (event.detail.key === key) {
        setStoredValue(event.detail.value);
      }
    };

    window.addEventListener("storage", handleStorageChange);
    window.addEventListener(
      "local-storage-change",
      handleLocalChange as EventListener
    );

    return () => {
      window.removeEventListener("storage", handleStorageChange);
      window.removeEventListener(
        "local-storage-change",
        handleLocalChange as EventListener
      );
    };
  }, [key, initialValue]);

  // Re-read value on mount to handle hydration mismatches
  useEffect(() => {
    setStoredValue(readStoredValue());
  }, [readStoredValue]);

  return [storedValue, setValue];
}

/**
 * Hook to remove a value from localStorage
 *
 * @param key - The localStorage key to manage
 * @returns Function to remove the stored value
 *
 * @example
 * const removeUser = useLocalStorageRemove('user-data');
 * // Later...
 * removeUser(); // Clears 'user-data' from localStorage
 */
export function useLocalStorageRemove(key: string): () => void {
  return useCallback(() => {
    if (isBrowser) {
      try {
        window.localStorage.removeItem(key);
        window.dispatchEvent(new StorageEvent("storage", { key, newValue: null }));
      } catch (error) {
        console.warn(`[useLocalStorage] Error removing key "${key}":`, error);
      }
    }
  }, [key]);
}