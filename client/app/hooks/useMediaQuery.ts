import { useState, useEffect, useCallback } from "react";

/**
 * Check if we're in a browser environment (not SSR)
 */
const isBrowser = typeof window !== "undefined";

/**
 * Custom hook that tracks whether a CSS media query matches.
 * Updates automatically when the viewport changes.
 *
 * Features:
 * - Real-time updates on viewport changes
 * - SSR-safe (returns false during SSR)
 * - Cleans up listeners on unmount
 * - Supports any valid CSS media query
 *
 * @param query - CSS media query string (e.g., '(max-width: 768px)')
 * @returns Boolean indicating if the media query matches
 *
 * @example
 * // Basic usage
 * function ResponsiveComponent() {
 *   const isMobile = useMediaQuery('(max-width: 768px)');
 *
 *   return (
 *     <div>
 *       {isMobile ? <MobileLayout /> : <DesktopLayout />}
 *     </div>
 *   );
 * }
 *
 * @example
 * // Multiple breakpoints
 * function AdaptiveNav() {
 *   const isSmall = useMediaQuery('(max-width: 640px)');
 *   const isMedium = useMediaQuery('(min-width: 641px) and (max-width: 1024px)');
 *   const isLarge = useMediaQuery('(min-width: 1025px)');
 *
 *   if (isSmall) return <MobileNav />;
 *   if (isMedium) return <TabletNav />;
 *   return <DesktopNav />;
 * }
 *
 * @example
 * // Feature queries
 * const prefersReducedMotion = useMediaQuery('(prefers-reduced-motion: reduce)');
 * const prefersDark = useMediaQuery('(prefers-color-scheme: dark)');
 * const supportsHover = useMediaQuery('(hover: hover)');
 */
export function useMediaQuery(query: string): boolean {
  // Get initial match state
  const getMatches = useCallback((): boolean => {
    if (!isBrowser) {
      return false;
    }
    return window.matchMedia(query).matches;
  }, [query]);

  const [matches, setMatches] = useState<boolean>(getMatches);

  useEffect(() => {
    if (!isBrowser) return;

    const mediaQueryList = window.matchMedia(query);

    // Update state with initial value (handles hydration)
    setMatches(mediaQueryList.matches);

    // Define listener
    const handleChange = (event: MediaQueryListEvent) => {
      setMatches(event.matches);
    };

    // Modern browsers support addEventListener on MediaQueryList
    // Older browsers only support addListener (deprecated)
    if (mediaQueryList.addEventListener) {
      mediaQueryList.addEventListener("change", handleChange);
    } else {
      // Fallback for older browsers
      mediaQueryList.addListener(handleChange);
    }

    // Cleanup
    return () => {
      if (mediaQueryList.removeEventListener) {
        mediaQueryList.removeEventListener("change", handleChange);
      } else {
        mediaQueryList.removeListener(handleChange);
      }
    };
  }, [query]);

  return matches;
}

/**
 * Tailwind CSS default breakpoints
 * sm: 640px, md: 768px, lg: 1024px, xl: 1280px, 2xl: 1536px
 */
const BREAKPOINTS = {
  sm: 640,
  md: 768,
  lg: 1024,
  xl: 1280,
  "2xl": 1536,
} as const;

/**
 * Hook to detect if viewport is mobile sized (max-width: 640px)
 * Aligns with Tailwind's 'sm' breakpoint
 *
 * @returns Boolean indicating if viewport is mobile sized
 *
 * @example
 * function Header() {
 *   const isMobile = useIsMobile();
 *   return isMobile ? <HamburgerMenu /> : <NavLinks />;
 * }
 */
export function useIsMobile(): boolean {
  return useMediaQuery(`(max-width: ${BREAKPOINTS.sm}px)`);
}

/**
 * Hook to detect if viewport is tablet sized (641px - 1024px)
 * Between Tailwind's 'sm' and 'lg' breakpoints
 *
 * @returns Boolean indicating if viewport is tablet sized
 *
 * @example
 * function Sidebar() {
 *   const isTablet = useIsTablet();
 *   return isTablet ? <CollapsedSidebar /> : <ExpandedSidebar />;
 * }
 */
export function useIsTablet(): boolean {
  return useMediaQuery(
    `(min-width: ${BREAKPOINTS.sm + 1}px) and (max-width: ${BREAKPOINTS.lg}px)`
  );
}

/**
 * Hook to detect if viewport is desktop sized (min-width: 1025px)
 * Above Tailwind's 'lg' breakpoint
 *
 * @returns Boolean indicating if viewport is desktop sized
 *
 * @example
 * function Layout() {
 *   const isDesktop = useIsDesktop();
 *   return isDesktop ? <ThreeColumnLayout /> : <SingleColumnLayout />;
 * }
 */
export function useIsDesktop(): boolean {
  return useMediaQuery(`(min-width: ${BREAKPOINTS.lg + 1}px)`);
}

/**
 * Hook to detect user's preferred color scheme
 *
 * @returns 'dark' | 'light' based on system preference
 *
 * @example
 * function App() {
 *   const colorScheme = usePreferredColorScheme();
 *   return <ThemeProvider theme={colorScheme}>...</ThemeProvider>;
 * }
 */
export function usePreferredColorScheme(): "dark" | "light" {
  const prefersDark = useMediaQuery("(prefers-color-scheme: dark)");
  return prefersDark ? "dark" : "light";
}

/**
 * Hook to detect if user prefers reduced motion
 *
 * @returns Boolean indicating if user prefers reduced motion
 *
 * @example
 * function AnimatedComponent() {
 *   const prefersReducedMotion = usePrefersReducedMotion();
 *
 *   return (
 *     <motion.div
 *       animate={{ opacity: 1, y: 0 }}
 *       transition={{ duration: prefersReducedMotion ? 0 : 0.3 }}
 *     />
 *   );
 * }
 */
export function usePrefersReducedMotion(): boolean {
  return useMediaQuery("(prefers-reduced-motion: reduce)");
}

/**
 * Hook to get all breakpoint states at once
 *
 * @returns Object with boolean flags for each breakpoint
 *
 * @example
 * function ResponsiveComponent() {
 *   const { isMobile, isTablet, isDesktop, isSmall, isMedium, isLarge } = useBreakpoints();
 *
 *   return (
 *     <div className={isLarge ? 'p-8' : isMedium ? 'p-4' : 'p-2'}>
 *       Content
 *     </div>
 *   );
 * }
 */
export function useBreakpoints() {
  const isMobile = useIsMobile();
  const isTablet = useIsTablet();
  const isDesktop = useIsDesktop();

  // Also provide more granular breakpoints matching Tailwind
  const isSmall = useMediaQuery(`(min-width: ${BREAKPOINTS.sm}px)`);
  const isMedium = useMediaQuery(`(min-width: ${BREAKPOINTS.md}px)`);
  const isLarge = useMediaQuery(`(min-width: ${BREAKPOINTS.lg}px)`);
  const isXLarge = useMediaQuery(`(min-width: ${BREAKPOINTS.xl}px)`);
  const is2XLarge = useMediaQuery(`(min-width: ${BREAKPOINTS["2xl"]}px)`);

  return {
    isMobile,
    isTablet,
    isDesktop,
    // Tailwind-style (min-width based, true if >= breakpoint)
    isSmall,
    isMedium,
    isLarge,
    isXLarge,
    is2XLarge,
  };
}