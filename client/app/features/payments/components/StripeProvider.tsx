import { useMemo, type ReactNode } from "react";
import { loadStripe, type Stripe } from "@stripe/stripe-js";
import { Elements } from "@stripe/react-stripe-js";

export interface StripeProviderProps {
  /** Child components that need access to Stripe */
  children: ReactNode;
  /** Optional override for Stripe publishable key (defaults to env variable) */
  publishableKey?: string;
}

/**
 * Get the Stripe publishable key from environment.
 */
function getStripePublishableKey(): string | null {
  return import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || null;
}

/**
 * Check if Stripe is configured.
 * @returns true if VITE_STRIPE_PUBLISHABLE_KEY is set
 */
export function isStripeConfigured(): boolean {
  const key = getStripePublishableKey();
  return Boolean(key && key !== "pk_test_your_key_here");
}

// Stripe instance promise (cached)
let stripePromise: Promise<Stripe | null> | null = null;

/**
 * Get or initialize the Stripe instance.
 */
function getStripePromise(publishableKey?: string): Promise<Stripe | null> {
  const key = publishableKey || getStripePublishableKey();

  if (!key || key === "pk_test_your_key_here") {
    return Promise.resolve(null);
  }

  if (!stripePromise) {
    stripePromise = loadStripe(key);
  }

  return stripePromise;
}

/**
 * StripeProvider component wraps children with Stripe Elements context.
 * Loads Stripe.js with the publishable key from environment variables.
 *
 * @example
 * <StripeProvider>
 *   <CheckoutForm clientSecret="..." amount={5000} onSuccess={handleSuccess} />
 * </StripeProvider>
 */
export function StripeProvider({
  children,
  publishableKey,
}: StripeProviderProps) {
  // Memoize Stripe promise to prevent re-initialization
  const stripe = useMemo(
    () => getStripePromise(publishableKey),
    [publishableKey]
  );

  // Check if Stripe is properly configured
  if (!isStripeConfigured() && !publishableKey) {
    return (
      <div
        className="p-4 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800"
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
              Stripe Not Configured
            </h4>
            <p className="mt-1 text-sm text-amber-700 dark:text-amber-400">
              The VITE_STRIPE_PUBLISHABLE_KEY environment variable is not set.
              Please add it to your .env file to enable payments.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <Elements
      stripe={stripe}
      options={{
        appearance: {
          theme: "stripe",
          variables: {
            colorPrimary: "#0f766e",
            colorBackground: "#ffffff",
            colorText: "#1f2937",
            colorDanger: "#dc2626",
            fontFamily:
              'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            borderRadius: "8px",
          },
        },
      }}
    >
      {children}
    </Elements>
  );
}
