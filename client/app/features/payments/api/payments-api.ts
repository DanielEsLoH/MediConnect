import api from "~/lib/api";
import type {
  Payment,
  PaymentsListResponse,
  PaymentResponse,
  CreatePaymentIntentPayload,
  CreatePaymentIntentResponse,
  ConfirmPaymentPayload,
  ConfirmPaymentResponse,
  CreateMockPaymentPayload,
} from "../types";

/**
 * Payments API service.
 * Handles all payment-related API calls including listing, creation, and Stripe integration.
 */
export const paymentsApi = {
  /**
   * Get all payments for the current user.
   * @returns List of payments
   */
  getPayments: async (): Promise<Payment[]> => {
    const response = await api.get<PaymentsListResponse>("/payments");
    return response.data.data;
  },

  /**
   * Get a single payment by ID.
   * @param id - Payment's unique identifier
   * @returns Payment details
   */
  getPaymentById: async (id: number): Promise<Payment> => {
    const response = await api.get<PaymentResponse>(`/payments/${id}`);
    return response.data.data;
  },

  /**
   * Create a new payment intent for Stripe checkout.
   * @param payload - Payment intent creation payload with appointment ID and amount
   * @returns Payment ID and Stripe client secret
   */
  createPaymentIntent: async (
    payload: CreatePaymentIntentPayload
  ): Promise<CreatePaymentIntentResponse> => {
    const response = await api.post<CreatePaymentIntentResponse>(
      "/payments/create-intent",
      payload
    );
    return response.data;
  },

  /**
   * Confirm a payment after Stripe checkout completes.
   * @param payload - Payment confirmation payload with payment ID and payment intent ID
   * @returns Updated payment data
   */
  confirmPayment: async (payload: ConfirmPaymentPayload): Promise<Payment> => {
    const response = await api.post<ConfirmPaymentResponse>(
      "/payments/confirm",
      payload
    );
    return response.data.data;
  },

  /**
   * Create a mock payment for development/testing purposes.
   * This bypasses Stripe and directly creates a completed payment record.
   * @param payload - Mock payment creation payload
   * @returns Created payment data
   */
  createMockPayment: async (payload: CreateMockPaymentPayload): Promise<Payment> => {
    const response = await api.post<PaymentResponse>("/payments/mock", payload);
    return response.data.data;
  },
};
