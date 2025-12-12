import { useState, useCallback, useEffect } from "react";
import { useMutation } from "@tanstack/react-query";
import { useBookingStore } from "../../store/bookingStore";
import { appointmentsApi } from "~/features/appointments";
import { paymentsApi } from "~/features/payments";
import { CheckoutForm } from "~/features/payments/components/CheckoutForm";
import { StripeProvider } from "~/features/payments/components/StripeProvider";
import { Button, Spinner } from "~/components/ui";
import { cn } from "~/lib/utils";
import type { CreateAppointmentPayload } from "~/features/appointments";

export interface PaymentStepProps {
  /** Doctor ID for the appointment */
  doctorId: number;
  /** Consultation fee */
  consultationFee: number;
  /** Callback when step is completed */
  onNext: () => void;
  /** Callback to go back */
  onBack: () => void;
}

/**
 * Payment Step (Step 5)
 *
 * Handles the payment flow:
 * 1. Create appointment (if not already created)
 * 2. Create payment intent
 * 3. Display Stripe checkout form
 * 4. Confirm payment on success
 * 5. Proceed to confirmation step
 */
export function PaymentStep({
  doctorId,
  consultationFee,
  onNext,
  onBack,
}: PaymentStepProps) {
  const {
    selectedDate,
    startTime,
    endTime,
    consultationType,
    reason,
    appointmentId,
    paymentClientSecret,
    paymentId,
    setAppointmentId,
    setPaymentIntent,
    setPaymentSuccess,
  } = useBookingStore();

  const [error, setError] = useState<string | null>(null);
  const [paymentCompleted, setPaymentCompleted] = useState(false);

  // Calculate amount in cents
  const amountInCents = consultationFee * 100;

  // Create appointment mutation
  const createAppointmentMutation = useMutation({
    mutationFn: (payload: CreateAppointmentPayload) =>
      appointmentsApi.createAppointment(payload),
    onSuccess: (appointment) => {
      setAppointmentId(appointment.id);
    },
    onError: (err) => {
      const message =
        err instanceof Error
          ? err.message
          : "Failed to create appointment. Please try again.";
      setError(message);
    },
  });

  // Create payment intent mutation
  const createPaymentIntentMutation = useMutation({
    mutationFn: (appointmentIdParam: number) =>
      paymentsApi.createPaymentIntent({
        appointment_id: appointmentIdParam,
        amount: amountInCents,
      }),
    onSuccess: (data) => {
      setPaymentIntent(data.client_secret, data.payment_id);
    },
    onError: (err) => {
      const message =
        err instanceof Error
          ? err.message
          : "Failed to initialize payment. Please try again.";
      setError(message);
    },
  });

  // Confirm payment mutation
  const confirmPaymentMutation = useMutation({
    mutationFn: (stripePaymentIntentId: string) =>
      paymentsApi.confirmPayment({
        payment_id: paymentId!,
        payment_intent_id: stripePaymentIntentId,
      }),
    onSuccess: () => {
      setPaymentCompleted(true);
    },
    onError: (err) => {
      const message =
        err instanceof Error
          ? err.message
          : "Failed to confirm payment. Please contact support.";
      setError(message);
    },
  });

  // Initialize appointment and payment intent on mount
  useEffect(() => {
    if (!appointmentId && selectedDate && startTime && endTime && consultationType) {
      // Create appointment
      const payload: CreateAppointmentPayload = {
        appointment: {
          doctor_id: doctorId,
          appointment_date: selectedDate,
          start_time: startTime,
          end_time: endTime,
          consultation_type: consultationType,
          reason: reason || undefined,
        },
      };
      createAppointmentMutation.mutate(payload);
    } else if (appointmentId && !paymentClientSecret) {
      // Appointment exists, create payment intent
      createPaymentIntentMutation.mutate(appointmentId);
    }
  }, [appointmentId, paymentClientSecret]);

  // Handle payment success
  const handlePaymentSuccess = useCallback(
    (stripePaymentIntentId: string) => {
      setPaymentSuccess(stripePaymentIntentId);
      confirmPaymentMutation.mutate(stripePaymentIntentId);
    },
    [setPaymentSuccess, confirmPaymentMutation]
  );

  // Handle payment error
  const handlePaymentError = useCallback((errorMessage: string) => {
    setError(errorMessage);
  }, []);

  // Handle proceed to confirmation
  const handleProceed = useCallback(() => {
    if (paymentCompleted) {
      onNext();
    }
  }, [paymentCompleted, onNext]);

  // Loading state
  const isLoading =
    createAppointmentMutation.isPending ||
    createPaymentIntentMutation.isPending ||
    !paymentClientSecret;

  return (
    <div className="space-y-6">
      {/* Error Display */}
      {error && (
        <div
          className="flex items-start gap-3 p-4 bg-error-50 dark:bg-error-950 rounded-lg border border-error-200 dark:border-error-800"
          role="alert"
        >
          <svg
            className="w-5 h-5 text-error-600 dark:text-error-400 shrink-0 mt-0.5"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fillRule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
              clipRule="evenodd"
            />
          </svg>
          <div className="flex-1">
            <p className="text-sm font-medium text-error-900 dark:text-error-100">
              Payment Error
            </p>
            <p className="text-sm text-error-700 dark:text-error-300 mt-1">
              {error}
            </p>
          </div>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="flex flex-col items-center justify-center py-12">
          <Spinner size="lg" />
          <p className="mt-4 text-sm text-gray-600 dark:text-gray-400">
            {createAppointmentMutation.isPending
              ? "Creating your appointment..."
              : "Initializing secure payment..."}
          </p>
        </div>
      )}

      {/* Payment Completed State */}
      {paymentCompleted && (
        <div className="text-center py-8">
          <div className="w-16 h-16 rounded-full bg-success-100 dark:bg-success-900 flex items-center justify-center mx-auto mb-4">
            <svg
              className="w-8 h-8 text-success-600 dark:text-success-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M5 13l4 4L19 7"
              />
            </svg>
          </div>
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
            Payment Successful!
          </h3>
          <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">
            Your payment has been processed successfully.
          </p>
        </div>
      )}

      {/* Stripe Checkout Form */}
      {!isLoading && !paymentCompleted && paymentClientSecret && (
        <StripeProvider>
          <CheckoutForm
            clientSecret={paymentClientSecret}
            amount={amountInCents}
            currency="USD"
            onSuccess={handlePaymentSuccess}
            onError={handlePaymentError}
            disabled={confirmPaymentMutation.isPending}
          />
        </StripeProvider>
      )}

      {/* Navigation Buttons */}
      <div className="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-800">
        <Button
          variant="outline"
          onClick={onBack}
          disabled={isLoading || paymentCompleted || confirmPaymentMutation.isPending}
        >
          Back
        </Button>
        {paymentCompleted && (
          <Button
            variant="primary"
            onClick={handleProceed}
            className="min-w-[120px]"
          >
            View Confirmation
          </Button>
        )}
      </div>
    </div>
  );
}
