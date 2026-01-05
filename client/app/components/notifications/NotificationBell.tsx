import { useEffect, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { cn } from "~/lib/utils";
import { useClickOutside } from "~/hooks/useClickOutside";
import { useWebSocket } from "~/hooks/useWebSocket";
import { notificationsApi } from "~/features/notifications/api/notifications-api";
import { useNotificationStore } from "~/features/notifications/store/useNotificationStore";
import { NotificationPanel } from "./NotificationPanel";
import type { Notification } from "~/features/notifications/types";

/**
 * Props for NotificationBell component
 */
export interface NotificationBellProps {
  /** Additional CSS classes */
  className?: string;
}

/**
 * NotificationBell Component
 *
 * Header bell icon that displays unread notification count and toggles
 * the notification dropdown panel. Manages WebSocket connection for
 * real-time notification updates.
 *
 * Features:
 * - Unread count badge with animation for new notifications
 * - Click outside to close dropdown
 * - Keyboard accessible (Enter/Space to toggle, Escape to close)
 * - Real-time updates via WebSocket
 * - Screen reader announcements for new notifications
 *
 * @example
 * <NotificationBell />
 */
export function NotificationBell({ className }: NotificationBellProps) {
  const {
    unreadCount,
    isPanelOpen,
    setUnreadCount,
    setNotifications,
    togglePanel,
    closePanel,
  } = useNotificationStore();

  // Fetch initial notifications and unread count
  // Note: These queries are disabled until the backend endpoints are implemented
  // The backend currently returns 404 for /notifications/unread/count
  // and 500 for /notifications
  const { data: notificationsData } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => notificationsApi.getNotifications(1, 20),
    staleTime: 30000,
    retry: false, // Don't retry on error (backend may not have this endpoint)
    enabled: false, // Disabled until backend is ready
  });

  const { data: unreadCountData } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: notificationsApi.getUnreadCount,
    staleTime: 30000,
    refetchInterval: false, // Disabled until backend is ready
    retry: false, // Don't retry on error (backend may not have this endpoint)
    enabled: false, // Disabled until backend is ready
  });

  // Update store when data changes
  useEffect(() => {
    if (notificationsData?.data) {
      setNotifications(notificationsData.data);
    }
  }, [notificationsData, setNotifications]);

  useEffect(() => {
    if (unreadCountData !== undefined) {
      setUnreadCount(unreadCountData);
    }
  }, [unreadCountData, setUnreadCount]);

  // Handle new notification from WebSocket
  const handleNewNotification = useCallback((notification: Notification) => {
    // Show toast notification for new messages
    toast.custom(
      (t) => (
        <div
          className={cn(
            "max-w-md w-full bg-white dark:bg-gray-800 shadow-lg rounded-lg pointer-events-auto",
            "ring-1 ring-black ring-opacity-5 overflow-hidden",
            t.visible ? "animate-enter" : "animate-leave"
          )}
        >
          <div className="p-4">
            <div className="flex items-start">
              <div className="flex-shrink-0">
                <svg
                  className="h-6 w-6 text-primary-500"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                  />
                </svg>
              </div>
              <div className="ml-3 w-0 flex-1">
                <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                  {notification.title}
                </p>
                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400 line-clamp-2">
                  {notification.message}
                </p>
              </div>
              <div className="ml-4 flex-shrink-0 flex">
                <button
                  type="button"
                  className={cn(
                    "rounded-md inline-flex text-gray-400",
                    "hover:text-gray-500 dark:hover:text-gray-300",
                    "focus:outline-none focus:ring-2 focus:ring-primary-500"
                  )}
                  onClick={() => toast.dismiss(t.id)}
                >
                  <span className="sr-only">Close</span>
                  <svg className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path
                      fillRule="evenodd"
                      d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                      clipRule="evenodd"
                    />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      ),
      {
        duration: 5000,
        position: "top-right",
      }
    );
  }, []);

  // Initialize WebSocket connection for real-time updates
  // Note: Disabled until backend ActionCable/WebSocket support is implemented
  useWebSocket({
    enabled: false, // Disabled - backend doesn't have ActionCable configured yet
    onNotification: handleNewNotification,
  });

  // Click outside handler to close panel
  const containerRef = useClickOutside<HTMLDivElement>(closePanel, isPanelOpen);

  // Handle keyboard navigation
  const handleKeyDown = (event: React.KeyboardEvent) => {
    switch (event.key) {
      case "Enter":
      case " ":
        event.preventDefault();
        togglePanel();
        break;
      case "Escape":
        if (isPanelOpen) {
          event.preventDefault();
          closePanel();
        }
        break;
    }
  };

  // Format badge count (99+ for large numbers)
  const formatBadgeCount = (count: number): string => {
    if (count > 99) return "99+";
    return count.toString();
  };

  return (
    <div
      ref={containerRef}
      className={cn("relative", className)}
    >
      {/* Bell button */}
      <button
        type="button"
        className={cn(
          "relative",
          "p-2 rounded-lg",
          "text-gray-500 hover:text-gray-700",
          "dark:text-gray-400 dark:hover:text-gray-200",
          "hover:bg-gray-100 dark:hover:bg-gray-800",
          "transition-colors duration-150",
          "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
          // Touch-friendly size
          "min-h-[44px] min-w-[44px] flex items-center justify-center",
          // Active state when panel is open
          isPanelOpen && "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200"
        )}
        onClick={togglePanel}
        onKeyDown={handleKeyDown}
        aria-label={
          unreadCount > 0
            ? `Notifications, ${unreadCount} unread`
            : "Notifications"
        }
        aria-expanded={isPanelOpen}
        aria-haspopup="true"
        aria-controls="notification-panel"
      >
        {/* Bell icon */}
        <svg
          className="w-6 h-6"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
          />
        </svg>

        {/* Unread badge */}
        {unreadCount > 0 && (
          <span
            className={cn(
              "absolute -top-0.5 -right-0.5",
              "flex items-center justify-center",
              "min-w-[18px] h-[18px] px-1",
              "text-[10px] font-bold text-white",
              "bg-red-500 rounded-full",
              "ring-2 ring-white dark:ring-gray-900",
              // Animation for new notifications
              "animate-in zoom-in-50 duration-200"
            )}
            aria-hidden="true"
          >
            {formatBadgeCount(unreadCount)}
          </span>
        )}
      </button>

      {/* Screen reader live region for new notifications */}
      <div
        role="status"
        aria-live="polite"
        aria-atomic="true"
        className="sr-only"
      >
        {unreadCount > 0 && `You have ${unreadCount} unread notification${unreadCount !== 1 ? "s" : ""}`}
      </div>

      {/* Notification panel dropdown */}
      {isPanelOpen && (
        <div id="notification-panel">
          <NotificationPanel />
        </div>
      )}
    </div>
  );
}