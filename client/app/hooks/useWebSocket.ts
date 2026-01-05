import { useEffect, useRef, useCallback } from "react";
import { useAuthStore } from "~/store/useAuthStore";
import { useNotificationStore } from "~/features/notifications/store/useNotificationStore";
import type { Notification } from "~/features/notifications/types";

/**
 * WebSocket connection configuration
 */
interface WebSocketConfig {
  /** Enable/disable the connection */
  enabled?: boolean;
  /** Callback when a new notification is received */
  onNotification?: (notification: Notification) => void;
  /** Callback when connection is established */
  onConnect?: () => void;
  /** Callback when connection is closed */
  onDisconnect?: () => void;
  /** Callback when an error occurs */
  onError?: (error: Event) => void;
}

/**
 * WebSocket hook return type
 */
interface UseWebSocketReturn {
  /** Whether the WebSocket is connected */
  isConnected: boolean;
  /** Manually reconnect */
  reconnect: () => void;
  /** Manually disconnect */
  disconnect: () => void;
}

// ActionCable message types
interface ActionCableMessage {
  type?: string;
  message?: {
    type: string;
    notification?: Notification;
  };
  identifier?: string;
}

/**
 * Custom hook for WebSocket connection using ActionCable protocol.
 * Connects to the notifications channel for real-time updates.
 *
 * @param config - WebSocket configuration options
 * @returns Connection status and control methods
 *
 * @example
 * const { isConnected, reconnect } = useWebSocket({
 *   enabled: isAuthenticated,
 *   onNotification: (notification) => console.log('New:', notification),
 * });
 */
export function useWebSocket(config: WebSocketConfig = {}): UseWebSocketReturn {
  const {
    enabled = true,
    onNotification,
    onConnect,
    onDisconnect,
    onError,
  } = config;

  const { token, isAuthenticated } = useAuthStore();
  const { addNotification, setConnected, isConnected } = useNotificationStore();

  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const maxReconnectAttempts = 5;
  const baseReconnectDelay = 1000;

  // Get WebSocket URL from environment or default
  const getWebSocketUrl = useCallback(() => {
    const baseUrl =
      import.meta.env.VITE_WS_URL ||
      import.meta.env.VITE_API_BASE_URL?.replace(/^http/, "ws") ||
      "ws://localhost:3000";

    // Remove /api/v1 suffix if present and add /cable
    const wsUrl = baseUrl.replace(/\/api\/v1$/, "") + "/cable";
    return wsUrl;
  }, []);

  /**
   * Send a message through the WebSocket
   */
  const sendMessage = useCallback((message: object) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message));
    }
  }, []);

  /**
   * Subscribe to the notifications channel
   */
  const subscribeToChannel = useCallback(() => {
    const identifier = JSON.stringify({
      channel: "NotificationsChannel",
    });

    sendMessage({
      command: "subscribe",
      identifier,
    });
  }, [sendMessage]);

  /**
   * Connect to WebSocket
   */
  const connect = useCallback(() => {
    if (!enabled || !isAuthenticated || !token) {
      return;
    }

    // Don't create a new connection if one exists
    if (
      wsRef.current?.readyState === WebSocket.OPEN ||
      wsRef.current?.readyState === WebSocket.CONNECTING
    ) {
      return;
    }

    const url = getWebSocketUrl();

    try {
      // Create WebSocket with token in URL params (ActionCable style)
      const wsUrl = new URL(url);
      wsUrl.searchParams.set("token", token);

      wsRef.current = new WebSocket(wsUrl.toString());

      wsRef.current.onopen = () => {
        console.log("[WebSocket] Connected");
        reconnectAttemptsRef.current = 0;
        setConnected(true);
        onConnect?.();

        // Subscribe to notifications channel after connection
        subscribeToChannel();
      };

      wsRef.current.onmessage = (event: MessageEvent) => {
        try {
          const data: ActionCableMessage = JSON.parse(event.data);

          // Handle ActionCable ping/welcome messages
          if (data.type === "ping" || data.type === "welcome") {
            return;
          }

          // Handle confirmation of subscription
          if (data.type === "confirm_subscription") {
            console.log("[WebSocket] Subscribed to notifications channel");
            return;
          }

          // Handle incoming notification
          if (data.message?.type === "notification" && data.message.notification) {
            const notification = data.message.notification;
            addNotification(notification);
            onNotification?.(notification);
          }
        } catch (error) {
          console.error("[WebSocket] Failed to parse message:", error);
        }
      };

      wsRef.current.onclose = (event) => {
        console.log("[WebSocket] Disconnected:", event.code, event.reason);
        setConnected(false);
        onDisconnect?.();

        // Attempt to reconnect if not a clean close
        if (event.code !== 1000 && enabled && isAuthenticated) {
          scheduleReconnect();
        }
      };

      wsRef.current.onerror = (error) => {
        console.error("[WebSocket] Error:", error);
        onError?.(error);
      };
    } catch (error) {
      console.error("[WebSocket] Failed to connect:", error);
    }
  }, [
    enabled,
    isAuthenticated,
    token,
    getWebSocketUrl,
    subscribeToChannel,
    setConnected,
    addNotification,
    onConnect,
    onDisconnect,
    onNotification,
    onError,
  ]);

  /**
   * Schedule a reconnection attempt with exponential backoff
   */
  const scheduleReconnect = useCallback(() => {
    if (reconnectAttemptsRef.current >= maxReconnectAttempts) {
      console.log("[WebSocket] Max reconnection attempts reached");
      return;
    }

    const delay =
      baseReconnectDelay * Math.pow(2, reconnectAttemptsRef.current);
    console.log(
      `[WebSocket] Reconnecting in ${delay}ms (attempt ${reconnectAttemptsRef.current + 1}/${maxReconnectAttempts})`
    );

    reconnectTimeoutRef.current = setTimeout(() => {
      reconnectAttemptsRef.current++;
      connect();
    }, delay);
  }, [connect]);

  /**
   * Disconnect from WebSocket
   */
  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
      reconnectTimeoutRef.current = null;
    }

    if (wsRef.current) {
      wsRef.current.close(1000, "Client disconnecting");
      wsRef.current = null;
    }

    setConnected(false);
  }, [setConnected]);

  /**
   * Manually reconnect
   */
  const reconnect = useCallback(() => {
    disconnect();
    reconnectAttemptsRef.current = 0;
    connect();
  }, [disconnect, connect]);

  // Connect on mount, disconnect on unmount
  useEffect(() => {
    if (enabled && isAuthenticated) {
      connect();
    }

    return () => {
      disconnect();
    };
  }, [enabled, isAuthenticated, connect, disconnect]);

  // Reconnect when token changes
  useEffect(() => {
    if (token && enabled && isAuthenticated) {
      reconnect();
    }
  }, [token]);

  return {
    isConnected,
    reconnect,
    disconnect,
  };
}