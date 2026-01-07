import { useState, useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { Button, Card, CardHeader, CardTitle, CardContent, Spinner } from "~/components/ui";
import { cn } from "~/lib/utils";
import {
  paymentsApi,
  PaymentHistoryTable,
  CheckoutForm,
  StripeProvider,
  isStripeConfigured,
  type Payment,
} from "~/features/payments";

/**
 * Query keys for payments.
 */
const paymentKeys = {
  all: ["payments"] as const,
  list: () => [...paymentKeys.all, "list"] as const,
  detail: (id: number) => [...paymentKeys.all, "detail", id] as const,
};

/**
 * Mock mode warning banner component.
 */
function MockModeBanner() {
  return (
    <div
      className="mb-6 p-4 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800"
      role="alert"
    >
      <div className="flex items-start gap-3">
        <svg
          className="w-5 h-5 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
          />
        </svg>
        <div>
          <h4 className="text-sm font-medium text-amber-800 dark:text-amber-300">
            Development Mode
          </h4>
          <p className="mt-1 text-sm text-amber-700 dark:text-amber-400">
            Stripe is not configured. Using mock mode for development. Set{" "}
            <code className="px-1.5 py-0.5 bg-amber-100 dark:bg-amber-900/40 rounded text-xs font-mono">
              VITE_STRIPE_PUBLISHABLE_KEY
            </code>{" "}
            in your .env file to enable real payments.
          </p>
        </div>
      </div>
    </div>
  );
}

/**
 * Test Payment section for development/demo purposes.
 */
interface TestPaymentSectionProps {
  onPaymentCreated: () => void;
}

function TestPaymentSection({ onPaymentCreated }: TestPaymentSectionProps) {
  const stripeConfigured = isStripeConfigured();
  const [testAmount, setTestAmount] = useState("50.00");
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [paymentId, setPaymentId] = useState<number | null>(null);

  // Mock payment mutation
  const mockPaymentMutation = useMutation({
    mutationFn: () =>
      paymentsApi.createMockPayment({
        appointment_id: 1, // Mock appointment ID
        amount: Math.round(parseFloat(testAmount) * 100), // Convert to cents
        description: "Test payment (mock mode)",
      }),
    onSuccess: () => {
      toast.success("Mock payment created successfully!");
      onPaymentCreated();
    },
    onError: (error) => {
      const message =
        error instanceof Error ? error.message : "Failed to create mock payment";
      toast.error(message);
    },
  });

  // Create payment intent mutation (for real Stripe payments)
  const createIntentMutation = useMutation({
    mutationFn: () =>
      paymentsApi.createPaymentIntent({
        appointment_id: 1, // Mock appointment ID
        amount: Math.round(parseFloat(testAmount) * 100), // Convert to cents
      }),
    onSuccess: (data) => {
      setClientSecret(data.client_secret);
      setPaymentId(data.payment_id);
    },
    onError: (error) => {
      const message =
        error instanceof Error
          ? error.message
          : "Failed to create payment intent";
      toast.error(message);
    },
  });

  // Confirm payment mutation
  const confirmPaymentMutation = useMutation({
    mutationFn: (paymentIntentId: string) =>
      paymentsApi.confirmPayment({
        payment_id: paymentId!,
        payment_intent_id: paymentIntentId,
      }),
    onSuccess: () => {
      toast.success("Payment completed successfully!");
      setClientSecret(null);
      setPaymentId(null);
      onPaymentCreated();
    },
    onError: (error) => {
      const message =
        error instanceof Error ? error.message : "Failed to confirm payment";
      toast.error(message);
    },
  });

  const handleMockPayment = useCallback(() => {
    mockPaymentMutation.mutate();
  }, [mockPaymentMutation]);

  const handleCreateIntent = useCallback(() => {
    createIntentMutation.mutate();
  }, [createIntentMutation]);

  const handlePaymentSuccess = useCallback(
    (paymentIntentId: string) => {
      confirmPaymentMutation.mutate(paymentIntentId);
    },
    [confirmPaymentMutation]
  );

  const handlePaymentError = useCallback((error: string) => {
    toast.error(error);
  }, []);

  const handleCancelCheckout = useCallback(() => {
    setClientSecret(null);
    setPaymentId(null);
  }, []);

  const isLoading =
    mockPaymentMutation.isPending ||
    createIntentMutation.isPending ||
    confirmPaymentMutation.isPending;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Test Payment</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
          Use this section to test the payment flow. In a real application, payments
          would be initiated from the appointment booking process.
        </p>

        {/* Show checkout form if we have a client secret */}
        {clientSecret && stripeConfigured ? (
          <div className="space-y-4">
            <StripeProvider>
              <CheckoutForm
                clientSecret={clientSecret}
                amount={Math.round(parseFloat(testAmount) * 100)}
                onSuccess={handlePaymentSuccess}
                onError={handlePaymentError}
                disabled={confirmPaymentMutation.isPending}
              />
            </StripeProvider>
            <Button
              variant="ghost"
              fullWidth
              onClick={handleCancelCheckout}
              disabled={confirmPaymentMutation.isPending}
            >
              Cancel
            </Button>
          </div>
        ) : (
          <div className="space-y-4">
            {/* Amount Input */}
            <div>
              <label
                htmlFor="test-amount"
                className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
              >
                Test Amount (USD)
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">
                  $
                </span>
                <input
                  id="test-amount"
                  type="number"
                  min="0.50"
                  step="0.01"
                  value={testAmount}
                  onChange={(e) => setTestAmount(e.target.value)}
                  disabled={isLoading}
                  className={cn(
                    "w-full rounded-lg border bg-white transition-colors duration-200",
                    "pl-7 pr-3 py-3 text-base sm:py-2.5 sm:text-sm",
                    "min-h-[44px] sm:min-h-[40px]",
                    "text-gray-900 placeholder:text-gray-400",
                    "border-gray-300 hover:border-gray-400",
                    "focus:outline-none focus:ring-2 focus:ring-primary-500/20 focus:border-primary-500",
                    "dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700",
                    isLoading && "opacity-60 cursor-not-allowed"
                  )}
                />
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col sm:flex-row gap-3">
              {stripeConfigured ? (
                <Button
                  variant="primary"
                  fullWidth
                  onClick={handleCreateIntent}
                  isLoading={createIntentMutation.isPending}
                  loadingText="Initializing..."
                  disabled={isLoading || !testAmount || parseFloat(testAmount) < 0.5}
                >
                  Pay with Stripe
                </Button>
              ) : (
                <Button
                  variant="primary"
                  fullWidth
                  onClick={handleMockPayment}
                  isLoading={mockPaymentMutation.isPending}
                  loadingText="Processing..."
                  disabled={isLoading || !testAmount || parseFloat(testAmount) < 0.5}
                >
                  Create Mock Payment
                </Button>
              )}
            </div>

            {/* Mode Indicator */}
            <p className="text-xs text-center text-gray-500 dark:text-gray-400">
              {stripeConfigured ? (
                <span className="flex items-center justify-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-success-500" />
                  Stripe is configured - real payments enabled
                </span>
              ) : (
                <span className="flex items-center justify-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-amber-500" />
                  Mock mode - no real charges will be made
                </span>
              )}
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

/**
 * Error state component.
 */
interface ErrorStateProps {
  message: string;
  onRetry: () => void;
}

function ErrorState({ message, onRetry }: ErrorStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 sm:py-16 text-center">
      <div className="w-16 h-16 rounded-full bg-error-100 dark:bg-error-900/30 flex items-center justify-center mb-4">
        <svg
          className="w-8 h-8 text-error-600 dark:text-error-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
          />
        </svg>
      </div>
      <h2 className="text-lg font-medium text-gray-900 dark:text-gray-100">
        Unable to Load Payments
      </h2>
      <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">
        {message}
      </p>
      <Button variant="primary" onClick={onRetry} className="mt-6">
        Try Again
      </Button>
    </div>
  );
}

/**
 * Payments Page Component
 *
 * Displays payment history and provides a test payment section.
 * Features:
 * - Payment history table with status badges
 * - Mock payment mode when Stripe is not configured
 * - Real Stripe checkout when configured
 * - Loading, error, and empty states
 * - Responsive layout
 */
export default function PaymentsPage() {
  const queryClient = useQueryClient();
  const stripeConfigured = isStripeConfigured();

  // Fetch payments
  // Note: Backend payments endpoint may not be fully implemented yet
  const {
    data: payments,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: paymentKeys.list(),
    queryFn: paymentsApi.getPayments,
    staleTime: 1000 * 60 * 2, // Consider data fresh for 2 minutes
    retry: false, // Don't retry - backend may not have this endpoint
  });

  // Handle view payment details
  const handleViewDetails = useCallback((id: number) => {
    // In a full implementation, this would open a modal or navigate to a detail page
    toast.success(`Viewing payment #${id}`);
  }, []);

  // Handle payment created (refresh list)
  const handlePaymentCreated = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: paymentKeys.list() });
  }, [queryClient]);

  // Loading state
  if (isLoading) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Payments
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            View your payment history and manage transactions.
          </p>
        </div>

        {/* Loading State */}
        <div className="flex items-center justify-center py-16">
          <Spinner size="lg" label="Loading payments..." />
        </div>
      </>
    );
  }

  // Error state
  if (isError) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Payments
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            View your payment history and manage transactions.
          </p>
        </div>

        <ErrorState
          message={
            error instanceof Error
              ? error.message
              : "An error occurred while loading your payments."
          }
          onRetry={() => refetch()}
        />
      </>
    );
  }

  return (
    <>
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Payments
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          View your payment history and manage transactions.
        </p>
      </div>

      {/* Mock Mode Banner */}
      {!stripeConfigured && <MockModeBanner />}

      {/* Two-Column Layout on Desktop */}
      <div className="grid gap-8 lg:grid-cols-3">
        {/* Payment History Section - Takes 2 columns */}
        <section className="lg:col-span-2" aria-labelledby="history-heading">
          <Card>
            <CardHeader>
              <CardTitle as="h2" className="flex items-center gap-2">
                <svg
                  className="w-5 h-5 text-gray-500"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                  />
                </svg>
                <span id="history-heading">Payment History</span>
              </CardTitle>
            </CardHeader>
            <CardContent className="-mx-4 sm:-mx-5 md:-mx-6 -mb-4 sm:-mb-5 md:-mb-6">
              <PaymentHistoryTable
                payments={payments || []}
                onViewDetails={handleViewDetails}
              />
            </CardContent>
          </Card>
        </section>

        {/* Test Payment Section - Takes 1 column */}
        <section aria-labelledby="test-payment-heading">
          <TestPaymentSection onPaymentCreated={handlePaymentCreated} />
        </section>
      </div>
    </>
  );
}
