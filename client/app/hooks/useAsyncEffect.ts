import { useEffect, useRef, type DependencyList } from "react";

/**
 * Custom hook for running async effects safely.
 *
 * This hook solves common problems with async operations in useEffect:
 * - Prevents state updates after component unmount
 * - Provides a cancellation mechanism for cleanup
 * - Handles race conditions when dependencies change rapidly
 *
 * @param effect - Async function that receives an isCancelled callback
 * @param deps - Dependency array (same as useEffect)
 *
 * @example
 * // Basic async data fetching
 * function UserProfile({ userId }: { userId: string }) {
 *   const [user, setUser] = useState<User | null>(null);
 *   const [loading, setLoading] = useState(true);
 *
 *   useAsyncEffect(async (isCancelled) => {
 *     setLoading(true);
 *     try {
 *       const data = await fetchUser(userId);
 *       // Check if cancelled before updating state
 *       if (!isCancelled()) {
 *         setUser(data);
 *       }
 *     } catch (error) {
 *       if (!isCancelled()) {
 *         console.error('Failed to fetch user:', error);
 *       }
 *     } finally {
 *       if (!isCancelled()) {
 *         setLoading(false);
 *       }
 *     }
 *   }, [userId]);
 *
 *   return loading ? <Spinner /> : <UserCard user={user} />;
 * }
 *
 * @example
 * // Multiple async operations
 * useAsyncEffect(async (isCancelled) => {
 *   const [users, posts] = await Promise.all([
 *     fetchUsers(),
 *     fetchPosts()
 *   ]);
 *
 *   if (!isCancelled()) {
 *     setUsers(users);
 *     setPosts(posts);
 *   }
 * }, []);
 *
 * @example
 * // With AbortController for fetch cancellation
 * useAsyncEffect(async (isCancelled) => {
 *   const controller = new AbortController();
 *
 *   try {
 *     const response = await fetch('/api/data', {
 *       signal: controller.signal
 *     });
 *     const data = await response.json();
 *
 *     if (!isCancelled()) {
 *       setData(data);
 *     }
 *   } catch (error) {
 *     if (error instanceof Error && error.name === 'AbortError') {
 *       // Request was cancelled, ignore
 *       return;
 *     }
 *     if (!isCancelled()) {
 *       setError(error);
 *     }
 *   }
 *
 *   // Note: You could also abort on cleanup, but isCancelled() handles this
 * }, []);
 */
export function useAsyncEffect(
  effect: (isCancelled: () => boolean) => Promise<void>,
  deps: DependencyList
): void {
  useEffect(() => {
    let cancelled = false;

    const isCancelled = () => cancelled;

    // Execute the async effect
    effect(isCancelled).catch((error) => {
      // Only log if not cancelled - cancelled errors are expected
      if (!cancelled) {
        console.error("[useAsyncEffect] Unhandled error in async effect:", error);
      }
    });

    // Cleanup function sets cancelled flag
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
}

/**
 * Custom hook for running async effects with cleanup support.
 * Similar to useAsyncEffect but also accepts a cleanup function.
 *
 * @param effect - Async function that receives isCancelled callback and returns optional cleanup
 * @param deps - Dependency array
 *
 * @example
 * // With cleanup
 * useAsyncEffectWithCleanup(async (isCancelled) => {
 *   const subscription = await subscribeToUpdates(userId);
 *
 *   if (!isCancelled()) {
 *     setConnected(true);
 *   }
 *
 *   // Return cleanup function
 *   return () => {
 *     subscription.unsubscribe();
 *   };
 * }, [userId]);
 */
export function useAsyncEffectWithCleanup(
  effect: (isCancelled: () => boolean) => Promise<void | (() => void)>,
  deps: DependencyList
): void {
  const cleanupRef = useRef<(() => void) | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;
    const isCancelled = () => cancelled;

    effect(isCancelled)
      .then((cleanup) => {
        if (!cancelled && cleanup) {
          cleanupRef.current = cleanup;
        }
      })
      .catch((error) => {
        if (!cancelled) {
          console.error(
            "[useAsyncEffectWithCleanup] Unhandled error in async effect:",
            error
          );
        }
      });

    return () => {
      cancelled = true;
      if (cleanupRef.current) {
        cleanupRef.current();
        cleanupRef.current = undefined;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
}

/**
 * Creates an AbortController that automatically aborts on cleanup.
 * Useful for cancelling fetch requests when component unmounts.
 *
 * @param deps - Dependency array (controller recreated when deps change)
 * @returns AbortSignal to pass to fetch requests
 *
 * @example
 * function DataFetcher({ url }: { url: string }) {
 *   const signal = useAbortSignal([url]);
 *   const [data, setData] = useState(null);
 *
 *   useEffect(() => {
 *     fetch(url, { signal })
 *       .then(res => res.json())
 *       .then(setData)
 *       .catch(err => {
 *         if (err.name !== 'AbortError') {
 *           console.error(err);
 *         }
 *       });
 *   }, [url, signal]);
 *
 *   return data ? <DataDisplay data={data} /> : <Loading />;
 * }
 */
export function useAbortSignal(deps: DependencyList = []): AbortSignal {
  const controllerRef = useRef<AbortController | null>(null);

  useEffect(() => {
    // Create new controller
    controllerRef.current = new AbortController();

    // Abort on cleanup
    return () => {
      controllerRef.current?.abort();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  // Create initial controller if it doesn't exist
  if (!controllerRef.current) {
    controllerRef.current = new AbortController();
  }

  return controllerRef.current.signal;
}