import api from "~/lib/api";
import type {
  VideoTokenResponse,
  VideoSessionResponse,
  EndVideoSessionResponse,
} from "../types";

/**
 * Video consultation API service.
 * Handles all video-related API calls for the LiveKit video consultation system.
 */
export const videoApi = {
  /**
   * Get a LiveKit access token for joining a video consultation.
   * The token is generated based on the appointment ID and the authenticated user.
   *
   * @param appointmentId - The appointment ID to join
   * @returns Video token response with token, server URL, and room name
   * @throws Error if appointment doesn't exist, user is not authorized, or appointment is not a video consultation
   */
  getVideoToken: async (
    appointmentId: string
  ): Promise<VideoTokenResponse["data"]> => {
    const response = await api.post<VideoTokenResponse>(
      `/appointments/${appointmentId}/video/token`
    );
    return response.data.data;
  },

  /**
   * Get details about an existing video session.
   * Returns session information including status, participants, and metadata.
   *
   * @param appointmentId - The appointment ID associated with the video session
   * @returns Video session details
   * @throws Error if session doesn't exist or user is not authorized
   */
  getVideoSession: async (
    appointmentId: string
  ): Promise<VideoSessionResponse["data"]> => {
    const response = await api.get<VideoSessionResponse>(
      `/appointments/${appointmentId}/video/session`
    );
    return response.data.data;
  },

  /**
   * End an active video session.
   * This will disconnect all participants and mark the session as completed.
   * Only the session host (usually the doctor) can end the session.
   *
   * @param appointmentId - The appointment ID associated with the video session
   * @returns Success response with message
   * @throws Error if session doesn't exist, user is not authorized to end it
   */
  endVideoSession: async (
    appointmentId: string
  ): Promise<EndVideoSessionResponse["data"]> => {
    const response = await api.post<EndVideoSessionResponse>(
      `/appointments/${appointmentId}/video/end`
    );
    return response.data.data;
  },

  /**
   * Check if a video session is available for an appointment.
   * Used to determine if the "Join Video" button should be shown.
   *
   * @param appointmentId - The appointment ID to check
   * @returns Whether a video session can be joined
   */
  checkVideoAvailability: async (
    appointmentId: string
  ): Promise<{ available: boolean; reason?: string }> => {
    try {
      const response = await api.get<{
        data: { available: boolean; reason?: string };
      }>(`/appointments/${appointmentId}/video/availability`);
      return response.data.data;
    } catch (error: unknown) {
      // If endpoint doesn't exist or returns error, video is not available
      if (
        error &&
        typeof error === "object" &&
        "response" in error &&
        (error as { response?: { status?: number } }).response?.status === 404
      ) {
        return { available: false, reason: "Video consultation not available" };
      }
      throw error;
    }
  },

  /**
   * Report a connection issue or quality problem.
   * Used for monitoring and support purposes.
   *
   * @param appointmentId - The appointment ID
   * @param issue - Description of the issue
   * @param metrics - Optional quality metrics at time of issue
   */
  reportIssue: async (
    appointmentId: string,
    issue: string,
    metrics?: Record<string, unknown>
  ): Promise<void> => {
    await api.post(`/appointments/${appointmentId}/video/report`, {
      issue,
      metrics,
      timestamp: new Date().toISOString(),
    });
  },
};