import { create } from "zustand";
import type { Notification } from "../types";

/**
 * Notification store state interface
 */
interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  isLoading: boolean;
  isPanelOpen: boolean;
  isConnected: boolean;
}

/**
 * Notification store actions interface
 */
interface NotificationActions {
  setNotifications: (notifications: Notification[]) => void;
  addNotification: (notification: Notification) => void;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
  removeNotification: (id: string) => void;
  setUnreadCount: (count: number) => void;
  decrementUnreadCount: () => void;
  setIsLoading: (loading: boolean) => void;
  togglePanel: () => void;
  openPanel: () => void;
  closePanel: () => void;
  setConnected: (connected: boolean) => void;
  reset: () => void;
}

type NotificationStore = NotificationState & NotificationActions;

const initialState: NotificationState = {
  notifications: [],
  unreadCount: 0,
  isLoading: false,
  isPanelOpen: false,
  isConnected: false,
};

/**
 * Notification store for managing in-app notifications.
 * Handles real-time updates via WebSocket and local state management.
 *
 * @example
 * const { notifications, unreadCount, addNotification } = useNotificationStore();
 */
export const useNotificationStore = create<NotificationStore>((set, get) => ({
  ...initialState,

  /**
   * Set the full list of notifications (replaces existing)
   */
  setNotifications: (notifications: Notification[]) => {
    set({ notifications });
  },

  /**
   * Add a new notification to the top of the list
   */
  addNotification: (notification: Notification) => {
    const { notifications, unreadCount } = get();
    // Check if notification already exists
    if (notifications.some((n) => n.id === notification.id)) {
      return;
    }
    set({
      notifications: [notification, ...notifications],
      unreadCount: notification.read_at ? unreadCount : unreadCount + 1,
    });
  },

  /**
   * Mark a notification as read (update local state)
   */
  markAsRead: (id: string) => {
    const { notifications, unreadCount } = get();
    const notification = notifications.find((n) => n.id === id);

    // Only decrement if notification was unread
    if (notification && !notification.read_at) {
      set({
        notifications: notifications.map((n) =>
          n.id === id ? { ...n, read_at: new Date().toISOString() } : n
        ),
        unreadCount: Math.max(0, unreadCount - 1),
      });
    }
  },

  /**
   * Mark all notifications as read
   */
  markAllAsRead: () => {
    const { notifications } = get();
    set({
      notifications: notifications.map((n) => ({
        ...n,
        read_at: n.read_at || new Date().toISOString(),
      })),
      unreadCount: 0,
    });
  },

  /**
   * Remove a notification from the list
   */
  removeNotification: (id: string) => {
    const { notifications, unreadCount } = get();
    const notification = notifications.find((n) => n.id === id);
    const wasUnread = notification && !notification.read_at;

    set({
      notifications: notifications.filter((n) => n.id !== id),
      unreadCount: wasUnread ? Math.max(0, unreadCount - 1) : unreadCount,
    });
  },

  /**
   * Set the unread count (from API response)
   */
  setUnreadCount: (count: number) => {
    set({ unreadCount: count });
  },

  /**
   * Decrement unread count by 1
   */
  decrementUnreadCount: () => {
    const { unreadCount } = get();
    set({ unreadCount: Math.max(0, unreadCount - 1) });
  },

  /**
   * Set loading state
   */
  setIsLoading: (loading: boolean) => {
    set({ isLoading: loading });
  },

  /**
   * Toggle the notification panel open/closed
   */
  togglePanel: () => {
    const { isPanelOpen } = get();
    set({ isPanelOpen: !isPanelOpen });
  },

  /**
   * Open the notification panel
   */
  openPanel: () => {
    set({ isPanelOpen: true });
  },

  /**
   * Close the notification panel
   */
  closePanel: () => {
    set({ isPanelOpen: false });
  },

  /**
   * Set WebSocket connection status
   */
  setConnected: (connected: boolean) => {
    set({ isConnected: connected });
  },

  /**
   * Reset store to initial state
   */
  reset: () => {
    set(initialState);
  },
}));