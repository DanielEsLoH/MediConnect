import { useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { cn } from "~/lib/utils";
import { notificationsApi } from "~/features/notifications/api/notifications-api";
import { useNotificationStore } from "~/features/notifications/store/useNotificationStore";
import { NotificationItem } from "./NotificationItem";
import { Button } from "~/components/ui";

/**
 * NotificationPanel Component
 *
 * Dropdown panel that displays a list of notifications.
 * Supports loading states, empty states, and actions like mark all as read.
 */
export function NotificationPanel() {
  const queryClient = useQueryClient();
  const {
    notifications,
    setNotifications,
    setUnreadCount,
    markAsRead,
    markAllAsRead: markAllAsReadLocal,
    removeNotification,
    closePanel,
    isConnected,
  } = useNotificationStore();

  // Fetch notifications
  const { isLoading, error } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => notificationsApi.getNotifications(1, 20),
    staleTime: 30000, // 30 seconds
  });

  // Fetch unread count
  const { data: unreadCount } = useQuery({
    queryKey: ["notifications", "unread-count"],
    queryFn: notificationsApi.getUnreadCount,
    staleTime: 30000,
  });

  // Update store when data changes
  useEffect(() => {
    if (unreadCount !== undefined) {
      setUnreadCount(unreadCount);
    }
  }, [unreadCount, setUnreadCount]);

  // Mark single notification as read mutation
  const markAsReadMutation = useMutation({
    mutationFn: notificationsApi.markAsRead,
    onSuccess: (_, id) => {
      markAsRead(id);
      queryClient.invalidateQueries({ queryKey: ["notifications", "unread-count"] });
    },
    onError: () => {
      toast.error("Failed to mark notification as read");
    },
  });

  // Mark all as read mutation
  const markAllAsReadMutation = useMutation({
    mutationFn: notificationsApi.markAllAsRead,
    onSuccess: () => {
      markAllAsReadLocal();
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
      queryClient.invalidateQueries({ queryKey: ["notifications", "unread-count"] });
      toast.success("All notifications marked as read");
    },
    onError: () => {
      toast.error("Failed to mark all as read");
    },
  });

  // Delete notification mutation
  const deleteMutation = useMutation({
    mutationFn: notificationsApi.deleteNotification,
    onSuccess: (_, id) => {
      removeNotification(id);
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
      queryClient.invalidateQueries({ queryKey: ["notifications", "unread-count"] });
    },
    onError: () => {
      toast.error("Failed to delete notification");
    },
  });

  const handleMarkAsRead = (id: string) => {
    markAsReadMutation.mutate(id);
  };

  const handleMarkAllAsRead = () => {
    markAllAsReadMutation.mutate();
  };

  const handleDelete = (id: string) => {
    deleteMutation.mutate(id);
  };

  const hasUnread = notifications.some((n) => !n.read_at);

  return (
    <div
      className={cn(
        "absolute right-0 top-full mt-2",
        "w-80 sm:w-96",
        "bg-white dark:bg-gray-900",
        "border border-gray-200 dark:border-gray-700",
        "rounded-lg shadow-lg",
        "overflow-hidden",
        "z-50"
      )}
    >
      {/* Header */}
      <div
        className={cn(
          "flex items-center justify-between",
          "px-4 py-3",
          "border-b border-gray-200 dark:border-gray-700"
        )}
      >
        <div className="flex items-center gap-2">
          <h2 className="text-base font-semibold text-gray-900 dark:text-gray-100">
            Notifications
          </h2>
          {/* Connection status indicator */}
          <span
            className={cn(
              "w-2 h-2 rounded-full",
              isConnected ? "bg-green-500" : "bg-gray-400"
            )}
            title={isConnected ? "Connected" : "Disconnected"}
          />
        </div>

        {hasUnread && (
          <button
            type="button"
            className={cn(
              "text-sm text-primary-600 hover:text-primary-700",
              "dark:text-primary-400 dark:hover:text-primary-300",
              "disabled:opacity-50"
            )}
            onClick={handleMarkAllAsRead}
            disabled={markAllAsReadMutation.isPending}
          >
            Mark all read
          </button>
        )}
      </div>

      {/* Content */}
      <div className="max-h-96 overflow-y-auto">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary-600" />
          </div>
        ) : error ? (
          <div className="px-4 py-8 text-center">
            <p className="text-sm text-red-600 dark:text-red-400">
              Failed to load notifications
            </p>
            <Button
              variant="ghost"
              size="sm"
              className="mt-2"
              onClick={() => queryClient.invalidateQueries({ queryKey: ["notifications"] })}
            >
              Retry
            </Button>
          </div>
        ) : notifications.length === 0 ? (
          <div className="px-4 py-8 text-center">
            <div className="mx-auto w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-3">
              <svg
                className="w-6 h-6 text-gray-400"
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
            <p className="text-sm text-gray-500 dark:text-gray-400">
              No notifications yet
            </p>
            <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">
              We'll notify you when something important happens
            </p>
          </div>
        ) : (
          <div className="divide-y divide-gray-100 dark:divide-gray-800">
            {notifications.map((notification) => (
              <NotificationItem
                key={notification.id}
                notification={notification}
                onMarkAsRead={handleMarkAsRead}
                onDelete={handleDelete}
                onClick={() => {
                  // Close panel after clicking
                  closePanel();
                }}
              />
            ))}
          </div>
        )}
      </div>

      {/* Footer */}
      {notifications.length > 0 && (
        <div
          className={cn(
            "px-4 py-3",
            "border-t border-gray-200 dark:border-gray-700",
            "text-center"
          )}
        >
          <button
            type="button"
            className={cn(
              "text-sm text-primary-600 hover:text-primary-700",
              "dark:text-primary-400 dark:hover:text-primary-300"
            )}
            onClick={() => {
              closePanel();
              // Navigate to notifications page if it exists
              // navigate("/notifications");
            }}
          >
            View all notifications
          </button>
        </div>
      )}
    </div>
  );
}