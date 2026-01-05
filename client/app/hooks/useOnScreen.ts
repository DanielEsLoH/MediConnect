import { useState, useEffect, useRef, type RefObject } from "react";

/**
 * Check if we're in a browser environment (not SSR)
 */
const isBrowser = typeof window !== "undefined";

/**
 * Custom hook that uses Intersection Observer to detect when an element
 * is visible in the viewport.
 *
 * Features:
 * - Returns a ref to attach to the target element
 * - Returns visibility state as a boolean
 * - Configurable threshold, root, and rootMargin
 * - Automatically cleans up observer on unmount
 * - SSR-safe (returns false during SSR)
 *
 * @template T - The type of HTML element being observed
 * @param options - IntersectionObserver options (threshold, root, rootMargin)
 * @returns Tuple of [ref, isVisible]
 *
 * @example
 * // Basic lazy loading
 * function LazyImage({ src, alt }: { src: string; alt: string }) {
 *   const [ref, isVisible] = useOnScreen<HTMLDivElement>();
 *
 *   return (
 *     <div ref={ref}>
 *       {isVisible ? (
 *         <img src={src} alt={alt} />
 *       ) : (
 *         <div className="placeholder" />
 *       )}
 *     </div>
 *   );
 * }
 *
 * @example
 * // Infinite scroll
 * function InfiniteList({ items, loadMore }: Props) {
 *   const [sentinelRef, isVisible] = useOnScreen<HTMLDivElement>({
 *     threshold: 0,
 *     rootMargin: '100px' // Trigger 100px before visible
 *   });
 *
 *   useEffect(() => {
 *     if (isVisible) {
 *       loadMore();
 *     }
 *   }, [isVisible, loadMore]);
 *
 *   return (
 *     <div>
 *       {items.map(item => <ItemCard key={item.id} item={item} />)}
 *       <div ref={sentinelRef} /> {/* Invisible sentinel *\/}
 *     </div>
 *   );
 * }
 *
 * @example
 * // Animate on scroll
 * function AnimatedSection({ children }: { children: React.ReactNode }) {
 *   const [ref, isVisible] = useOnScreen<HTMLElement>({ threshold: 0.5 });
 *
 *   return (
 *     <section
 *       ref={ref}
 *       className={`transition-opacity duration-500 ${
 *         isVisible ? 'opacity-100' : 'opacity-0'
 *       }`}
 *     >
 *       {children}
 *     </section>
 *   );
 * }
 */
export function useOnScreen<T extends Element = HTMLDivElement>(
  options?: IntersectionObserverInit
): [RefObject<T | null>, boolean] {
  const ref = useRef<T>(null);
  const [isVisible, setIsVisible] = useState<boolean>(false);

  useEffect(() => {
    if (!isBrowser || !ref.current) return;

    // Check for IntersectionObserver support
    if (!("IntersectionObserver" in window)) {
      // Fallback: assume element is always visible
      setIsVisible(true);
      return;
    }

    const element = ref.current;

    const observer = new IntersectionObserver(([entry]) => {
      setIsVisible(entry.isIntersecting);
    }, options);

    observer.observe(element);

    return () => {
      observer.unobserve(element);
      observer.disconnect();
    };
  }, [options?.threshold, options?.root, options?.rootMargin]);

  return [ref, isVisible];
}

/**
 * Custom hook that tracks visibility and only triggers once (stays true after first visible).
 * Useful for "load once" scenarios like analytics or one-time animations.
 *
 * @template T - The type of HTML element being observed
 * @param options - IntersectionObserver options
 * @returns Tuple of [ref, hasBeenVisible]
 *
 * @example
 * // Load video only once visible (never unloads)
 * function LazyVideo({ src }: { src: string }) {
 *   const [ref, hasBeenVisible] = useOnScreenOnce<HTMLDivElement>();
 *
 *   return (
 *     <div ref={ref}>
 *       {hasBeenVisible && <video src={src} autoPlay />}
 *     </div>
 *   );
 * }
 *
 * @example
 * // Track impression analytics
 * function AdBanner({ adId }: { adId: string }) {
 *   const [ref, hasBeenSeen] = useOnScreenOnce<HTMLDivElement>({ threshold: 0.5 });
 *
 *   useEffect(() => {
 *     if (hasBeenSeen) {
 *       trackImpression(adId);
 *     }
 *   }, [hasBeenSeen, adId]);
 *
 *   return <div ref={ref}>Ad content</div>;
 * }
 */
export function useOnScreenOnce<T extends Element = HTMLDivElement>(
  options?: IntersectionObserverInit
): [RefObject<T | null>, boolean] {
  const ref = useRef<T>(null);
  const [hasBeenVisible, setHasBeenVisible] = useState<boolean>(false);

  useEffect(() => {
    if (!isBrowser || !ref.current || hasBeenVisible) return;

    if (!("IntersectionObserver" in window)) {
      setHasBeenVisible(true);
      return;
    }

    const element = ref.current;

    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setHasBeenVisible(true);
        // Stop observing after first intersection
        observer.unobserve(element);
        observer.disconnect();
      }
    }, options);

    observer.observe(element);

    return () => {
      observer.unobserve(element);
      observer.disconnect();
    };
  }, [hasBeenVisible, options?.threshold, options?.root, options?.rootMargin]);

  return [ref, hasBeenVisible];
}

/**
 * Custom hook for tracking visibility ratio (how much of element is visible).
 * Useful for parallax effects or progressive loading.
 *
 * @template T - The type of HTML element being observed
 * @param thresholds - Array of visibility thresholds to track (default: [0, 0.25, 0.5, 0.75, 1])
 * @param options - Additional IntersectionObserver options
 * @returns Tuple of [ref, intersectionRatio (0-1)]
 *
 * @example
 * // Progressive fade based on visibility
 * function ProgressiveFade({ children }: { children: React.ReactNode }) {
 *   const [ref, ratio] = useOnScreenRatio<HTMLDivElement>();
 *
 *   return (
 *     <div ref={ref} style={{ opacity: ratio }}>
 *       {children}
 *     </div>
 *   );
 * }
 *
 * @example
 * // Progress bar based on scroll
 * function ReadingProgress({ children }: { children: React.ReactNode }) {
 *   const [ref, ratio] = useOnScreenRatio<HTMLElement>(
 *     [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]
 *   );
 *
 *   return (
 *     <>
 *       <div className="fixed top-0 left-0 h-1 bg-blue-500"
 *            style={{ width: `${ratio * 100}%` }} />
 *       <article ref={ref}>{children}</article>
 *     </>
 *   );
 * }
 */
export function useOnScreenRatio<T extends Element = HTMLDivElement>(
  thresholds: number[] = [0, 0.25, 0.5, 0.75, 1],
  options?: Omit<IntersectionObserverInit, "threshold">
): [RefObject<T | null>, number] {
  const ref = useRef<T>(null);
  const [ratio, setRatio] = useState<number>(0);

  useEffect(() => {
    if (!isBrowser || !ref.current) return;

    if (!("IntersectionObserver" in window)) {
      setRatio(1);
      return;
    }

    const element = ref.current;

    const observer = new IntersectionObserver(
      ([entry]) => {
        setRatio(entry.intersectionRatio);
      },
      { ...options, threshold: thresholds }
    );

    observer.observe(element);

    return () => {
      observer.unobserve(element);
      observer.disconnect();
    };
  }, [thresholds, options?.root, options?.rootMargin]);

  return [ref, ratio];
}

/**
 * Custom hook for observing multiple elements at once.
 * Returns a Map of element IDs to their visibility state.
 *
 * @param options - IntersectionObserver options
 * @returns Object with register function and visibility map
 *
 * @example
 * function MultipleItems({ items }: { items: Item[] }) {
 *   const { register, visibilityMap } = useMultipleOnScreen({ threshold: 0.5 });
 *
 *   return (
 *     <div>
 *       {items.map(item => (
 *         <div
 *           key={item.id}
 *           ref={(el) => register(item.id, el)}
 *           className={visibilityMap.get(item.id) ? 'visible' : 'hidden'}
 *         >
 *           {item.content}
 *         </div>
 *       ))}
 *     </div>
 *   );
 * }
 */
export function useMultipleOnScreen(options?: IntersectionObserverInit): {
  register: (id: string, element: Element | null) => void;
  visibilityMap: Map<string, boolean>;
} {
  const [visibilityMap, setVisibilityMap] = useState<Map<string, boolean>>(
    new Map()
  );
  const observerRef = useRef<IntersectionObserver | null>(null);
  const elementsRef = useRef<Map<string, Element>>(new Map());

  useEffect(() => {
    if (!isBrowser) return;

    if (!("IntersectionObserver" in window)) {
      return;
    }

    observerRef.current = new IntersectionObserver((entries) => {
      setVisibilityMap((prev) => {
        const next = new Map(prev);
        entries.forEach((entry) => {
          // Find the ID for this element
          for (const [id, element] of elementsRef.current) {
            if (element === entry.target) {
              next.set(id, entry.isIntersecting);
              break;
            }
          }
        });
        return next;
      });
    }, options);

    // Observe all registered elements
    elementsRef.current.forEach((element) => {
      observerRef.current?.observe(element);
    });

    return () => {
      observerRef.current?.disconnect();
    };
  }, [options?.threshold, options?.root, options?.rootMargin]);

  const register = (id: string, element: Element | null) => {
    if (element) {
      elementsRef.current.set(id, element);
      observerRef.current?.observe(element);
    } else {
      const existing = elementsRef.current.get(id);
      if (existing) {
        observerRef.current?.unobserve(existing);
        elementsRef.current.delete(id);
      }
    }
  };

  return { register, visibilityMap };
}