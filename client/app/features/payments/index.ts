// Payments Feature Module
// Export all payment-related API functions, components, and types

// API
export { paymentsApi } from "./api/payments-api";

// Components
export { PaymentHistoryTable } from "./components/PaymentHistoryTable";
export { CheckoutForm } from "./components/CheckoutForm";
export { StripeProvider, isStripeConfigured } from "./components/StripeProvider";

// Types
export type {
  Payment,
  PaymentStatus,
  PaymentMethod,
  PaymentAppointment,
  CreatePaymentIntentPayload,
  CreatePaymentIntentResponse,
  ConfirmPaymentPayload,
  ConfirmPaymentResponse,
  CreateMockPaymentPayload,
  PaymentsListResponse,
  PaymentResponse,
} from "./types";
