/**
 * Payment status values representing the lifecycle of a payment.
 */
export type PaymentStatus =
  | "pending"
  | "processing"
  | "completed"
  | "failed"
  | "refunded";

/**
 * Payment method options available for transactions.
 */
export type PaymentMethod =
  | "credit_card"
  | "debit_card"
  | "wallet"
  | "insurance";

/**
 * Embedded appointment information in payment responses.
 */
export interface PaymentAppointment {
  /** Appointment unique identifier */
  id: number;
  /** Date of the appointment (YYYY-MM-DD format) */
  appointment_date: string;
  /** Start time of the appointment (HH:mm format) */
  start_time: string;
  /** Doctor information for the appointment */
  doctor?: {
    id: number;
    full_name: string;
    specialty: string;
  };
}

/**
 * Payment entity representing a financial transaction.
 */
export interface Payment {
  /** Unique identifier for the payment */
  id: number;
  /** ID of the user who made the payment */
  user_id: number;
  /** ID of the associated appointment (nullable if not linked) */
  appointment_id: number | null;
  /** Payment amount in the smallest currency unit (cents for USD) */
  amount: number;
  /** Currency code (e.g., "USD", "EUR") */
  currency: string;
  /** Current status of the payment */
  status: PaymentStatus;
  /** Method used for the payment */
  payment_method: PaymentMethod | null;
  /** Description or memo for the payment */
  description: string | null;
  /** Timestamp when the payment was completed (ISO 8601) */
  paid_at: string | null;
  /** Timestamp when the payment record was created (ISO 8601) */
  created_at: string;
  /** Timestamp when the payment record was last updated (ISO 8601) */
  updated_at?: string;
  /** Stripe Payment Intent ID (for Stripe payments) */
  stripe_payment_intent_id?: string | null;
  /** Embedded appointment information (optional, depends on API response) */
  appointment?: PaymentAppointment;
}

/**
 * Payload for creating a new payment intent.
 */
export interface CreatePaymentIntentPayload {
  /** ID of the appointment to pay for */
  appointment_id: number;
  /** Payment amount in cents */
  amount: number;
}

/**
 * Response from creating a payment intent.
 */
export interface CreatePaymentIntentResponse {
  /** Internal payment ID */
  payment_id: number;
  /** Stripe client secret for confirming the payment */
  client_secret: string;
  /** Stripe publishable key */
  publishable_key: string;
}

/**
 * Payload for confirming a payment.
 */
export interface ConfirmPaymentPayload {
  /** Internal payment ID */
  payment_id: number;
  /** Stripe Payment Intent ID */
  payment_intent_id: string;
}

/**
 * Response from payment confirmation.
 */
export interface ConfirmPaymentResponse {
  /** Updated payment data */
  data: Payment;
  /** Success message */
  message?: string;
}

/**
 * Payload for creating a mock payment (development mode).
 */
export interface CreateMockPaymentPayload {
  /** ID of the appointment to pay for */
  appointment_id: number;
  /** Payment amount in cents */
  amount: number;
  /** Description for the payment */
  description?: string;
}

/**
 * Response from fetching payments list.
 */
export interface PaymentsListResponse {
  data: Payment[];
}

/**
 * Response from fetching a single payment.
 */
export interface PaymentResponse {
  data: Payment;
}
