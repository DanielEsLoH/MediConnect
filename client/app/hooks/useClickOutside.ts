import { useEffect, useRef, type RefObject } from "react";

/**
 * Custom hook that detects clicks outside of the specified element.
 * Useful for closing dropdowns, modals, and other overlay components.
 *
 * @param handler - Callback function to execute when a click outside is detected
 * @param enabled - Whether the listener is active (default: true)
 * @returns Ref to attach to the element to monitor
 *
 * @example
 * function Dropdown() {
 *   const [isOpen, setIsOpen] = useState(false);
 *   const ref = useClickOutside(() => setIsOpen(false), isOpen);
 *
 *   return (
 *     <div ref={ref}>
 *       <button onClick={() => setIsOpen(true)}>Open</button>
 *       {isOpen && <div>Dropdown content</div>}
 *     </div>
 *   );
 * }
 */
export function useClickOutside<T extends HTMLElement = HTMLElement>(
  handler: () => void,
  enabled: boolean = true
): RefObject<T | null> {
  const ref = useRef<T>(null);

  useEffect(() => {
    if (!enabled) return;

    const handleClickOutside = (event: MouseEvent | TouchEvent) => {
      const target = event.target as Node;

      // Check if click is outside the ref element
      if (ref.current && !ref.current.contains(target)) {
        handler();
      }
    };

    // Use mousedown instead of click for better UX
    // (handles the case where user starts dragging inside and releases outside)
    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("touchstart", handleClickOutside);

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("touchstart", handleClickOutside);
    };
  }, [handler, enabled]);

  return ref;
}