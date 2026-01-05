/**
 * Video Consultation types for MediConnect
 * Types for the LiveKit-powered video consultation system
 */

/**
 * Status of a video session.
 */
export enum VideoSessionStatus {
  /** Waiting for participants to join */
  WAITING = "waiting",
  /** Attempting to connect to the video room */
  CONNECTING = "connecting",
  /** Successfully connected to the video room */
  CONNECTED = "connected",
  /** Disconnected from the video room */
  DISCONNECTED = "disconnected",
  /** An error occurred during the session */
  ERROR = "error",
}

/**
 * Video session entity representing an active video consultation.
 */
export interface VideoSession {
  /** Unique identifier for the video session */
  id: string;
  /** Associated appointment ID */
  appointment_id: string;
  /** LiveKit access token for joining the room */
  token: string;
  /** LiveKit room name */
  room_name: string;
  /** LiveKit server URL */
  server_url: string;
  /** Current status of the video session */
  status: VideoSessionStatus;
  /** When the session was created (ISO 8601) */
  created_at: string;
  /** When the session expires (ISO 8601) */
  expires_at: string;
  /** Session metadata */
  metadata?: VideoSessionMetadata;
}

/**
 * Additional metadata for a video session.
 */
export interface VideoSessionMetadata {
  /** Doctor's name for display */
  doctor_name: string;
  /** Doctor's specialty */
  doctor_specialty: string;
  /** Patient's name for display */
  patient_name: string;
  /** Scheduled appointment time */
  scheduled_time: string;
  /** Expected duration in minutes */
  duration_minutes: number;
}

/**
 * Information about a participant in the video call.
 */
export interface ParticipantInfo {
  /** Unique participant identity */
  identity: string;
  /** Display name of the participant */
  name: string;
  /** Whether the participant is the local user */
  isLocal: boolean;
  /** Whether the participant's camera is enabled */
  isCameraEnabled: boolean;
  /** Whether the participant's microphone is enabled */
  isMicrophoneEnabled: boolean;
  /** Whether the participant is currently speaking */
  isSpeaking: boolean;
  /** Whether the participant is sharing their screen */
  isScreenShareEnabled: boolean;
  /** Connection quality (0-5, where 5 is excellent) */
  connectionQuality: number;
  /** Role of the participant */
  role: ParticipantRole;
}

/**
 * Participant roles in a video consultation.
 */
export type ParticipantRole = "doctor" | "patient" | "observer";

/**
 * Payload for requesting a video token.
 */
export interface GetVideoTokenPayload {
  /** The appointment ID to join */
  appointment_id: string;
}

/**
 * API response for video token request.
 */
export interface VideoTokenResponse {
  data: {
    /** LiveKit access token */
    token: string;
    /** LiveKit server URL */
    server_url: string;
    /** Room name to join */
    room_name: string;
    /** Token expiration time (ISO 8601) */
    expires_at: string;
  };
}

/**
 * API response for video session details.
 */
export interface VideoSessionResponse {
  data: VideoSession;
}

/**
 * API response for ending a video session.
 */
export interface EndVideoSessionResponse {
  data: {
    success: boolean;
    message: string;
  };
}

/**
 * Device information for camera/microphone selection.
 */
export interface MediaDeviceInfo {
  /** Device unique identifier */
  deviceId: string;
  /** Human-readable device label */
  label: string;
  /** Type of device */
  kind: "audioinput" | "videoinput" | "audiooutput";
}

/**
 * Selected devices for the video call.
 */
export interface SelectedDevices {
  /** Selected camera device ID */
  videoDeviceId: string | null;
  /** Selected microphone device ID */
  audioDeviceId: string | null;
  /** Selected speaker device ID */
  audioOutputDeviceId: string | null;
}

/**
 * Connection state details.
 */
export interface ConnectionState {
  /** Current connection status */
  status: VideoSessionStatus;
  /** Error message if status is ERROR */
  error?: string;
  /** Number of reconnection attempts */
  reconnectAttempts: number;
  /** Whether currently attempting to reconnect */
  isReconnecting: boolean;
}

/**
 * Video call quality metrics.
 */
export interface VideoQualityMetrics {
  /** Video resolution width */
  width: number;
  /** Video resolution height */
  height: number;
  /** Current framerate */
  frameRate: number;
  /** Video bitrate in kbps */
  videoBitrate: number;
  /** Audio bitrate in kbps */
  audioBitrate: number;
  /** Packet loss percentage */
  packetLoss: number;
  /** Round trip time in ms */
  roundTripTime: number;
}

/**
 * Props for appointment info display in waiting room.
 */
export interface AppointmentInfo {
  /** Doctor's full name */
  doctorName: string;
  /** Doctor's specialty */
  doctorSpecialty: string;
  /** Scheduled date and time */
  scheduledTime: string;
  /** Expected duration in minutes */
  durationMinutes: number;
}