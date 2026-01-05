// Video Consultation Feature Module
// Export all video-related API functions and types

// API
export { videoApi } from "./api/video-api";

// Types
export {
  VideoSessionStatus,
  type VideoSession,
  type VideoSessionMetadata,
  type ParticipantInfo,
  type ParticipantRole,
  type GetVideoTokenPayload,
  type VideoTokenResponse,
  type VideoSessionResponse,
  type EndVideoSessionResponse,
  type MediaDeviceInfo,
  type SelectedDevices,
  type ConnectionState,
  type VideoQualityMetrics,
  type AppointmentInfo,
} from "./types";