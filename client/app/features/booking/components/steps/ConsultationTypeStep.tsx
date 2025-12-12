import { useState, useCallback } from "react";
import { useBookingStore } from "../../store/bookingStore";
import { Button } from "~/components/ui";
import { cn } from "~/lib/utils";
import type { ConsultationType } from "~/features/appointments";

export interface ConsultationTypeStepProps {
  /** Consultation fee for the doctor */
  consultationFee: number;
  /** Callback when step is completed */
  onNext: () => void;
  /** Callback to go back */
  onBack: () => void;
}

/**
 * Consultation type option configuration.
 */
interface ConsultationOption {
  type: ConsultationType;
  title: string;
  description: string;
  icon: React.ReactNode;
  priceModifier?: number; // Percentage adjustment (e.g., -10 for 10% discount)
}

/**
 * Consultation type options with metadata.
 */
const CONSULTATION_OPTIONS: ConsultationOption[] = [
  {
    type: "in_person",
    title: "In-Person Visit",
    description: "Visit the doctor's clinic for a face-to-face consultation",
    icon: (
      <svg
        className="w-6 h-6"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
        />
      </svg>
    ),
  },
  {
    type: "video",
    title: "Video Consultation",
    description: "Connect with the doctor remotely via secure video call",
    icon: (
      <svg
        className="w-6 h-6"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
        />
      </svg>
    ),
  },
  {
    type: "phone",
    title: "Phone Consultation",
    description: "Speak with the doctor over a phone call",
    icon: (
      <svg
        className="w-6 h-6"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
        />
      </svg>
    ),
    priceModifier: -10, // 10% discount for phone consultations
  },
];

/**
 * Format currency value.
 */
function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

/**
 * Calculate adjusted price based on consultation type.
 */
function calculatePrice(basePrice: number, modifier?: number): number {
  if (!modifier) return basePrice;
  return basePrice + (basePrice * modifier) / 100;
}

/**
 * Consultation Type Selection Step (Step 2)
 *
 * Allows user to choose:
 * - In-Person Visit
 * - Video Consultation
 * - Phone Consultation
 *
 * Displays price for each option (with potential modifiers).
 */
export function ConsultationTypeStep({
  consultationFee,
  onNext,
  onBack,
}: ConsultationTypeStepProps) {
  const { consultationType, setConsultationType } = useBookingStore();

  // Local state for UI
  const [selectedType, setSelectedType] = useState<ConsultationType | null>(
    consultationType
  );

  // Handle type selection
  const handleTypeSelect = useCallback((type: ConsultationType) => {
    setSelectedType(type);
  }, []);

  // Handle next button click
  const handleNext = useCallback(() => {
    if (!selectedType) return;

    // Save to store
    setConsultationType(selectedType);

    // Proceed to next step
    onNext();
  }, [selectedType, setConsultationType, onNext]);

  const canProceed = !!selectedType;

  return (
    <div className="space-y-6">
      {/* Consultation Type Options */}
      <div className="space-y-3">
        {CONSULTATION_OPTIONS.map((option) => {
          const isSelected = selectedType === option.type;
          const price = calculatePrice(consultationFee, option.priceModifier);
          const hasDiscount = option.priceModifier && option.priceModifier < 0;

          return (
            <button
              key={option.type}
              type="button"
              onClick={() => handleTypeSelect(option.type)}
              className={cn(
                "w-full p-4 rounded-lg border-2 transition-all duration-200",
                "flex items-start gap-4 text-left",
                "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
                isSelected
                  ? "border-primary-600 bg-primary-50 dark:bg-primary-950 dark:border-primary-400"
                  : "border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 bg-white dark:bg-gray-900"
              )}
              aria-pressed={isSelected}
            >
              {/* Icon */}
              <div
                className={cn(
                  "shrink-0 w-12 h-12 rounded-lg flex items-center justify-center",
                  isSelected
                    ? "bg-primary-600 text-white"
                    : "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400"
                )}
              >
                {option.icon}
              </div>

              {/* Content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <h3
                      className={cn(
                        "text-base font-semibold",
                        isSelected
                          ? "text-primary-900 dark:text-primary-100"
                          : "text-gray-900 dark:text-gray-100"
                      )}
                    >
                      {option.title}
                    </h3>
                    <p
                      className={cn(
                        "mt-1 text-sm",
                        isSelected
                          ? "text-primary-700 dark:text-primary-300"
                          : "text-gray-500 dark:text-gray-400"
                      )}
                    >
                      {option.description}
                    </p>
                  </div>

                  {/* Price */}
                  <div className="shrink-0 text-right">
                    <p
                      className={cn(
                        "text-lg font-bold",
                        isSelected
                          ? "text-primary-900 dark:text-primary-100"
                          : "text-gray-900 dark:text-gray-100"
                      )}
                    >
                      {formatCurrency(price)}
                    </p>
                    {hasDiscount && (
                      <p className="text-xs text-success-600 dark:text-success-400 font-medium mt-0.5">
                        {Math.abs(option.priceModifier!)}% off
                      </p>
                    )}
                  </div>
                </div>
              </div>

              {/* Selection Indicator */}
              {isSelected && (
                <div className="shrink-0">
                  <svg
                    className="w-6 h-6 text-primary-600 dark:text-primary-400"
                    fill="currentColor"
                    viewBox="0 0 20 20"
                  >
                    <path
                      fillRule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clipRule="evenodd"
                    />
                  </svg>
                </div>
              )}
            </button>
          );
        })}
      </div>

      {/* Navigation Buttons */}
      <div className="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-800">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button
          variant="primary"
          onClick={handleNext}
          disabled={!canProceed}
          className="min-w-[120px]"
        >
          Next
        </Button>
      </div>

      {!selectedType && (
        <p className="text-center text-sm text-gray-500 dark:text-gray-400">
          Please select a consultation type to continue
        </p>
      )}
    </div>
  );
}
