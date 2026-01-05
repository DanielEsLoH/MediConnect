/**
 * Notification types for MediConnect
 */

/**
 * Notification type enum matching backend
 */
export type NotificationType =
  | "appointment_created"
  | "appointment_confirmed"
  | "appointment_reminder"
  | "appointment_cancelled"
  | "payment_completed"
  | "payment_failed"
  | "review_requested";

/**
 * Notification channel enum
 */
export type NotificationChannel = "email" | "push" | "sms" | "in_app";

/**
 * Notification model
 */
export interface Notification {
  id: string;
  user_id: string;
  notification_type: NotificationType;
  title: string;
  message: string;
  data: Record<string, unknown>;
  channels: NotificationChannel[];
  read_at: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * API response wrapper for notifications list
 */
export interface NotificationsResponse {
  data: Notification[];
  meta?: {
    total: number;
    page: number;
    per_page: number;
  };
}

/**
 * API response for single notification
 */
export interface NotificationResponse {
  data: Notification;
}

/**
 * API response for unread count
 */
export interface UnreadCountResponse {
  data: {
    count: number;
  };
}

/**
 * Notification preferences
 */
export interface NotificationPreferences {
  email_enabled: boolean;
  push_enabled: boolean;
  sms_enabled: boolean;
  appointment_reminders: boolean;
  payment_notifications: boolean;
  marketing_emails: boolean;
}

/**
 * WebSocket message types
 */
export interface WebSocketNotificationMessage {
  type: "notification";
  notification: Notification;
}

export interface WebSocketReadMessage {
  type: "read";
  notification_id: string;
}

export type WebSocketMessage =
  | WebSocketNotificationMessage
  | WebSocketReadMessage;