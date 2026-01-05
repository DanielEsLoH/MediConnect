/**
 * Reviews & Ratings types for MediConnect
 * Types for the patient-to-doctor review system
 */

/**
 * Individual review entity representing a patient's review of a doctor.
 */
export interface Review {
  /** Unique identifier for the review */
  id: string;
  /** ID of the doctor being reviewed */
  doctor_id: string;
  /** ID of the patient who wrote the review */
  patient_id: string;
  /** ID of the appointment this review is associated with */
  appointment_id: string;
  /** Rating value (1-5 stars) */
  rating: number;
  /** Optional title/headline for the review */
  title: string | null;
  /** Optional detailed comment/feedback */
  comment: string | null;
  /** When the review was created (ISO 8601) */
  created_at: string;
  /** When the review was last updated (ISO 8601) */
  updated_at: string;
  /** Display name of the patient (may be anonymized) */
  patient_name: string;
  /** Optional patient avatar URL */
  patient_avatar?: string | null;
  /** Whether this review is verified (completed appointment) */
  is_verified: boolean;
  /** Number of users who found this review helpful */
  helpful_count: number;
  /** Number of users who found this review not helpful */
  not_helpful_count: number;
  /** Whether the current user has voted on this review */
  user_vote?: "helpful" | "not_helpful" | null;
}

/**
 * Rating distribution showing count per star level.
 */
export interface RatingDistribution {
  /** Count of 5-star reviews */
  5: number;
  /** Count of 4-star reviews */
  4: number;
  /** Count of 3-star reviews */
  3: number;
  /** Count of 2-star reviews */
  2: number;
  /** Count of 1-star reviews */
  1: number;
}

/**
 * Aggregated review statistics for a doctor.
 */
export interface ReviewStats {
  /** Average rating (1.0 - 5.0) */
  average_rating: number;
  /** Total number of reviews */
  total_reviews: number;
  /** Breakdown of reviews by star rating */
  rating_distribution: RatingDistribution;
}

/**
 * Payload for creating a new review.
 */
export interface CreateReviewPayload {
  /** ID of the doctor being reviewed */
  doctor_id: string;
  /** ID of the appointment this review is for */
  appointment_id: string;
  /** Rating value (1-5) */
  rating: number;
  /** Optional title for the review */
  title?: string;
  /** Optional detailed comment */
  comment?: string;
}

/**
 * Payload for updating an existing review.
 */
export interface UpdateReviewPayload {
  /** Updated rating value (1-5) */
  rating?: number;
  /** Updated title */
  title?: string | null;
  /** Updated comment */
  comment?: string | null;
}

/**
 * Payload for voting on a review's helpfulness.
 */
export interface ReviewVotePayload {
  /** The vote type */
  vote: "helpful" | "not_helpful";
}

/**
 * Pagination metadata for review lists.
 */
export interface ReviewPaginationMeta {
  /** Current page number */
  page: number;
  /** Items per page */
  per_page: number;
  /** Total number of reviews */
  total: number;
  /** Total number of pages */
  total_pages: number;
}

/**
 * API response for a list of reviews.
 */
export interface ReviewsResponse {
  /** Array of review data */
  data: Review[];
  /** Pagination metadata */
  meta: ReviewPaginationMeta;
}

/**
 * API response for a single review.
 */
export interface ReviewResponse {
  /** Review data */
  data: Review;
}

/**
 * API response for review statistics.
 */
export interface ReviewStatsResponse {
  /** Statistics data */
  data: ReviewStats;
}

/**
 * Query parameters for fetching reviews.
 */
export interface GetReviewsParams {
  /** Page number for pagination */
  page?: number;
  /** Number of items per page */
  per_page?: number;
  /** Sort order for reviews */
  sort_by?: "created_at" | "rating" | "helpful_count";
  /** Sort direction */
  sort_order?: "asc" | "desc";
  /** Filter by rating value */
  rating?: number;
}