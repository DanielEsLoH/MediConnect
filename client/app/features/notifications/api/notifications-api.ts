import api from "~/lib/api";
import type {
  Notification,
  NotificationsResponse,
  NotificationResponse,
  UnreadCountResponse,
  NotificationPreferences,
} from "../types";

/**
 * Notifications API service.
 * Handles all notification-related API calls.
 */
export const notificationsApi = {
  /**
   * Get all notifications for the current user.
   * @param page - Page number for pagination
   * @param perPage - Number of items per page
   * @returns List of notifications with pagination meta
   */
  getNotifications: async (
    page: number = 1,
    perPage: number = 20
  ): Promise<NotificationsResponse> => {
    const response = await api.get<NotificationsResponse>("/notifications", {
      params: { page, per_page: perPage },
    });
    return response.data;
  },

  /**
   * Get unread notifications only.
   * @returns List of unread notifications
   */
  getUnreadNotifications: async (): Promise<Notification[]> => {
    const response = await api.get<NotificationsResponse>(
      "/notifications/unread"
    );
    return response.data.data;
  },

  /**
   * Get count of unread notifications.
   * @returns Unread notification count
   */
  getUnreadCount: async (): Promise<number> => {
    const response = await api.get<UnreadCountResponse>(
      "/notifications/unread_count"
    );
    return response.data.data.count;
  },

  /**
   * Mark a single notification as read.
   * @param id - Notification ID
   * @returns Updated notification
   */
  markAsRead: async (id: string): Promise<Notification> => {
    const response = await api.post<NotificationResponse>(
      `/notifications/${id}/read`
    );
    return response.data.data;
  },

  /**
   * Mark all notifications as read.
   * @returns Success status
   */
  markAllAsRead: async (): Promise<void> => {
    await api.post("/notifications/mark_all_read");
  },

  /**
   * Delete a notification.
   * @param id - Notification ID
   */
  deleteNotification: async (id: string): Promise<void> => {
    await api.delete(`/notifications/${id}`);
  },

  /**
   * Get notification preferences.
   * @returns User's notification preferences
   */
  getPreferences: async (): Promise<NotificationPreferences> => {
    const response = await api.get<{ data: NotificationPreferences }>(
      "/notifications/preferences"
    );
    return response.data.data;
  },

  /**
   * Update notification preferences.
   * @param preferences - Updated preferences
   * @returns Updated preferences
   */
  updatePreferences: async (
    preferences: Partial<NotificationPreferences>
  ): Promise<NotificationPreferences> => {
    const response = await api.put<{ data: NotificationPreferences }>(
      "/notifications/preferences",
      preferences
    );
    return response.data.data;
  },
};