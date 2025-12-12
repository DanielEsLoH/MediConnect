import { useState, useCallback, type FormEvent } from "react";
import { CardElement, useStripe, useElements } from "@stripe/react-stripe-js";
import type { StripeCardElementChangeEvent } from "@stripe/stripe-js";
import { Button, Input } from "~/components/ui";
import { cn } from "~/lib/utils";

export interface CheckoutFormProps {
  /** Stripe client secret for the payment intent */
  clientSecret: string;
  /** Amount to display (in cents) */
  amount: number;
  /** Currency code */
  currency?: string;
  /** Callback on successful payment */
  onSuccess: (paymentIntentId: string) => void;
  /** Callback on payment error */
  onError?: (error: string) => void;
  /** Whether the form is disabled (e.g., during processing) */
  disabled?: boolean;
  /** Additional CSS classes */
  className?: string;
}

/**
 * Format amount from cents to display format.
 */
function formatAmount(amount: number, currency: string): string {
  const formatter = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency.toUpperCase(),
    minimumFractionDigits: 2,
  });
  return formatter.format(amount / 100);
}

/**
 * CheckoutForm component using Stripe Elements.
 * Handles card input and payment confirmation.
 *
 * Must be wrapped in a StripeProvider component.
 *
 * @example
 * <StripeProvider>
 *   <CheckoutForm
 *     clientSecret="pi_xxx_secret_xxx"
 *     amount={5000}
 *     onSuccess={(id) => console.log('Payment successful', id)}
 *   />
 * </StripeProvider>
 */
export function CheckoutForm({
  clientSecret,
  amount,
  currency = "USD",
  onSuccess,
  onError,
  disabled = false,
  className,
}: CheckoutFormProps) {
  const stripe = useStripe();
  const elements = useElements();

  const [cardholderName, setCardholderName] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [cardComplete, setCardComplete] = useState(false);

  // Handle card element changes
  const handleCardChange = useCallback((event: StripeCardElementChangeEvent) => {
    setCardComplete(event.complete);
    if (event.error) {
      setError(event.error.message);
    } else {
      setError(null);
    }
  }, []);

  // Handle form submission
  const handleSubmit = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();

      if (!stripe || !elements) {
        // Stripe.js has not loaded yet
        setError("Payment system is not ready. Please try again.");
        return;
      }

      const cardElement = elements.getElement(CardElement);
      if (!cardElement) {
        setError("Card input not found. Please refresh and try again.");
        return;
      }

      if (!cardholderName.trim()) {
        setError("Please enter the cardholder name.");
        return;
      }

      setIsProcessing(true);
      setError(null);

      try {
        const { error: stripeError, paymentIntent } =
          await stripe.confirmCardPayment(clientSecret, {
            payment_method: {
              card: cardElement,
              billing_details: {
                name: cardholderName.trim(),
              },
            },
          });

        if (stripeError) {
          const errorMessage =
            stripeError.message || "Payment failed. Please try again.";
          setError(errorMessage);
          onError?.(errorMessage);
        } else if (paymentIntent?.status === "succeeded") {
          onSuccess(paymentIntent.id);
        } else if (paymentIntent?.status === "requires_action") {
          // Handle 3D Secure or other authentication
          setError(
            "Additional authentication required. Please complete the verification."
          );
        } else {
          setError("Payment could not be processed. Please try again.");
        }
      } catch (err) {
        const errorMessage =
          err instanceof Error ? err.message : "An unexpected error occurred.";
        setError(errorMessage);
        onError?.(errorMessage);
      } finally {
        setIsProcessing(false);
      }
    },
    [stripe, elements, clientSecret, cardholderName, onSuccess, onError]
  );

  const isFormDisabled = disabled || isProcessing || !stripe;
  const canSubmit = cardComplete && cardholderName.trim() && !isFormDisabled;

  return (
    <form onSubmit={handleSubmit} className={cn("space-y-5", className)}>
      {/* Amount Display */}
      <div className="text-center py-4 bg-gray-50 dark:bg-gray-800/50 rounded-lg">
        <p className="text-sm text-gray-500 dark:text-gray-400">Amount to pay</p>
        <p className="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
          {formatAmount(amount, currency)}
        </p>
      </div>

      {/* Cardholder Name */}
      <Input
        label="Cardholder Name"
        placeholder="John Doe"
        value={cardholderName}
        onChange={(e) => setCardholderName(e.target.value)}
        disabled={isFormDisabled}
        required
        autoComplete="cc-name"
      />

      {/* Card Element */}
      <div className="space-y-1.5">
        <label
          htmlFor="card-element"
          className="block text-sm font-medium text-gray-700 dark:text-gray-300"
        >
          Card Details
          <span className="text-error-500 ml-1" aria-hidden="true">
            *
          </span>
        </label>
        <div
          className={cn(
            "p-4 rounded-lg border bg-white transition-colors duration-200",
            "min-h-[48px]",
            error
              ? "border-error-500 focus-within:ring-2 focus-within:ring-error-500/20"
              : "border-gray-300 hover:border-gray-400 focus-within:border-primary-500 focus-within:ring-2 focus-within:ring-primary-500/20",
            isFormDisabled && "opacity-60 cursor-not-allowed bg-gray-50",
            "dark:bg-gray-900 dark:border-gray-700"
          )}
        >
          <CardElement
            id="card-element"
            options={{
              style: {
                base: {
                  fontSize: "16px",
                  color: "#1f2937",
                  fontFamily:
                    'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
                  "::placeholder": {
                    color: "#9ca3af",
                  },
                },
                invalid: {
                  color: "#dc2626",
                  iconColor: "#dc2626",
                },
              },
              disabled: isFormDisabled,
            }}
            onChange={handleCardChange}
          />
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div
          className="flex items-start gap-2 p-3 rounded-lg bg-error-50 dark:bg-error-900/20 border border-error-200 dark:border-error-800"
          role="alert"
        >
          <svg
            className="w-5 h-5 text-error-600 dark:text-error-400 shrink-0 mt-0.5"
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
          <p className="text-sm text-error-700 dark:text-error-300">{error}</p>
        </div>
      )}

      {/* Submit Button */}
      <Button
        type="submit"
        variant="primary"
        fullWidth
        disabled={!canSubmit}
        isLoading={isProcessing}
        loadingText="Processing payment..."
      >
        Pay {formatAmount(amount, currency)}
      </Button>

      {/* Security Note */}
      <p className="text-xs text-center text-gray-500 dark:text-gray-400 flex items-center justify-center gap-1.5">
        <svg
          className="w-4 h-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
          />
        </svg>
        Secured by Stripe. Your card details are never stored.
      </p>
    </form>
  );
}
