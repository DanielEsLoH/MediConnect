import api from "~/lib/api";
import type {
  Review,
  ReviewStats,
  ReviewsResponse,
  ReviewResponse,
  ReviewStatsResponse,
  CreateReviewPayload,
  UpdateReviewPayload,
  ReviewVotePayload,
  GetReviewsParams,
} from "../types";

/**
 * Reviews API service.
 * Handles all review-related API calls for the patient-to-doctor review system.
 */
export const reviewsApi = {
  /**
   * Get reviews for a specific doctor.
   * @param doctorId - Doctor's unique identifier
   * @param params - Optional query parameters for pagination and filtering
   * @returns Paginated list of reviews with metadata
   */
  getReviews: async (
    doctorId: string,
    params: GetReviewsParams = {}
  ): Promise<ReviewsResponse> => {
    const {
      page = 1,
      per_page = 10,
      sort_by = "created_at",
      sort_order = "desc",
      rating,
    } = params;

    const response = await api.get<ReviewsResponse>(
      `/doctors/${doctorId}/reviews`,
      {
        params: {
          page,
          per_page,
          sort_by,
          sort_order,
          ...(rating !== undefined && { rating }),
        },
      }
    );
    return response.data;
  },

  /**
   * Get aggregated review statistics for a doctor.
   * @param doctorId - Doctor's unique identifier
   * @returns Review statistics including average rating and distribution
   */
  getReviewStats: async (doctorId: string): Promise<ReviewStats> => {
    const response = await api.get<ReviewStatsResponse>(
      `/doctors/${doctorId}/reviews/stats`
    );
    return response.data.data;
  },

  /**
   * Get a single review by ID.
   * @param reviewId - Review's unique identifier
   * @returns Review details
   */
  getReviewById: async (reviewId: string): Promise<Review> => {
    const response = await api.get<ReviewResponse>(`/reviews/${reviewId}`);
    return response.data.data;
  },

  /**
   * Create a new review for a doctor.
   * @param payload - Review creation payload with doctor ID, appointment ID, rating, and optional title/comment
   * @returns Created review data
   */
  createReview: async (payload: CreateReviewPayload): Promise<Review> => {
    const response = await api.post<ReviewResponse>("/reviews", payload);
    return response.data.data;
  },

  /**
   * Update an existing review.
   * Only the review author can update their review.
   * @param reviewId - Review's unique identifier
   * @param payload - Updated review data
   * @returns Updated review data
   */
  updateReview: async (
    reviewId: string,
    payload: UpdateReviewPayload
  ): Promise<Review> => {
    const response = await api.patch<ReviewResponse>(
      `/reviews/${reviewId}`,
      payload
    );
    return response.data.data;
  },

  /**
   * Delete a review.
   * Only the review author can delete their review.
   * @param reviewId - Review's unique identifier
   */
  deleteReview: async (reviewId: string): Promise<void> => {
    await api.delete(`/reviews/${reviewId}`);
  },

  /**
   * Vote on a review's helpfulness.
   * Users can mark reviews as helpful or not helpful.
   * @param reviewId - Review's unique identifier
   * @param payload - Vote type (helpful or not_helpful)
   * @returns Updated review data with new vote counts
   */
  voteOnReview: async (
    reviewId: string,
    payload: ReviewVotePayload
  ): Promise<Review> => {
    const response = await api.post<ReviewResponse>(
      `/reviews/${reviewId}/vote`,
      payload
    );
    return response.data.data;
  },

  /**
   * Remove a vote from a review.
   * @param reviewId - Review's unique identifier
   * @returns Updated review data
   */
  removeVote: async (reviewId: string): Promise<Review> => {
    const response = await api.delete<ReviewResponse>(
      `/reviews/${reviewId}/vote`
    );
    return response.data.data;
  },

  /**
   * Check if the current user can review a specific appointment.
   * Reviews can only be created for completed appointments that haven't been reviewed yet.
   * @param appointmentId - Appointment's unique identifier
   * @returns Whether the user can submit a review
   */
  canReviewAppointment: async (
    appointmentId: string
  ): Promise<{ can_review: boolean; reason?: string }> => {
    const response = await api.get<{
      data: { can_review: boolean; reason?: string };
    }>(`/appointments/${appointmentId}/can-review`);
    return response.data.data;
  },

  /**
   * Get the current user's review for a specific appointment, if exists.
   * @param appointmentId - Appointment's unique identifier
   * @returns Review data if exists, null otherwise
   */
  getMyReviewForAppointment: async (
    appointmentId: string
  ): Promise<Review | null> => {
    try {
      const response = await api.get<ReviewResponse>(
        `/appointments/${appointmentId}/my-review`
      );
      return response.data.data;
    } catch (error: unknown) {
      // Return null if no review exists (404)
      if (
        error &&
        typeof error === "object" &&
        "response" in error &&
        (error as { response?: { status?: number } }).response?.status === 404
      ) {
        return null;
      }
      throw error;
    }
  },
};