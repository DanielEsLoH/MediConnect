import { useState, useCallback } from "react";
import { useBookingStore } from "../../store/bookingStore";
import { Button } from "~/components/ui";
import { cn } from "~/lib/utils";

export interface ReasonStepProps {
  /** Callback when step is completed */
  onNext: () => void;
  /** Callback to go back */
  onBack: () => void;
}

/**
 * Pre-defined reason categories for quick selection.
 */
const REASON_CATEGORIES = [
  "General Checkup",
  "Follow-up Visit",
  "New Symptoms",
  "Prescription Refill",
  "Test Results Discussion",
  "Second Opinion",
  "Other",
];

/**
 * Reason & Symptoms Step (Step 3)
 *
 * Allows user to:
 * - Select from pre-defined reason categories (optional quick select)
 * - Enter detailed reason/symptoms in free-text field
 * - Character limit: 500 characters
 *
 * This step is optional but recommended for better appointment preparation.
 */
export function ReasonStep({ onNext, onBack }: ReasonStepProps) {
  const { reason, setReason } = useBookingStore();

  // Local state for UI
  const [localReason, setLocalReason] = useState(reason);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const maxLength = 500;
  const remainingChars = maxLength - localReason.length;

  // Handle category selection
  const handleCategorySelect = useCallback(
    (category: string) => {
      setSelectedCategory(category);
      // Pre-fill text if empty
      if (!localReason.trim()) {
        setLocalReason(category === "Other" ? "" : category);
      }
    },
    [localReason]
  );

  // Handle text change
  const handleTextChange = useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      const value = e.target.value;
      if (value.length <= maxLength) {
        setLocalReason(value);
        // Clear category selection if user types custom text
        if (selectedCategory && value !== selectedCategory) {
          setSelectedCategory(null);
        }
      }
    },
    [selectedCategory, maxLength]
  );

  // Handle next button click
  const handleNext = useCallback(() => {
    // Save to store (even if empty, as this step is optional)
    setReason(localReason.trim());

    // Proceed to next step
    onNext();
  }, [localReason, setReason, onNext]);

  // Handle skip
  const handleSkip = useCallback(() => {
    setReason("");
    onNext();
  }, [setReason, onNext]);

  return (
    <div className="space-y-6">
      {/* Info Message */}
      <div className="flex items-start gap-3 p-4 bg-blue-50 dark:bg-blue-950 rounded-lg border border-blue-200 dark:border-blue-800">
        <svg
          className="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5"
          fill="currentColor"
          viewBox="0 0 20 20"
        >
          <path
            fillRule="evenodd"
            d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
            clipRule="evenodd"
          />
        </svg>
        <div className="flex-1">
          <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
            Optional but Recommended
          </p>
          <p className="text-sm text-blue-700 dark:text-blue-300 mt-1">
            Sharing your reason helps the doctor prepare for your appointment and
            provide better care.
          </p>
        </div>
      </div>

      {/* Quick Category Selection */}
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
          Select a category (optional)
        </label>
        <div className="flex flex-wrap gap-2">
          {REASON_CATEGORIES.map((category) => {
            const isSelected = selectedCategory === category;
            return (
              <button
                key={category}
                type="button"
                onClick={() => handleCategorySelect(category)}
                className={cn(
                  "px-4 py-2 rounded-lg text-sm font-medium transition-colors duration-200",
                  "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
                  isSelected
                    ? "bg-primary-600 text-white"
                    : "bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
                )}
              >
                {category}
              </button>
            );
          })}
        </div>
      </div>

      {/* Reason Text Area */}
      <div>
        <label
          htmlFor="reason-text"
          className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
        >
          Describe your symptoms or reason for visit
        </label>
        <textarea
          id="reason-text"
          value={localReason}
          onChange={handleTextChange}
          maxLength={maxLength}
          rows={6}
          placeholder="E.g., I've been experiencing headaches for the past week, mainly in the morning..."
          className={cn(
            "w-full rounded-lg border bg-white transition-colors duration-200",
            "px-3 py-3 text-base sm:text-sm",
            "text-gray-900 dark:text-gray-100",
            "border-gray-300 dark:border-gray-700",
            "hover:border-gray-400 dark:hover:border-gray-600",
            "focus:outline-none focus:ring-2 focus:ring-primary-500/20 focus:border-primary-500",
            "dark:bg-gray-900",
            "resize-none"
          )}
          aria-describedby="reason-helper char-count"
        />
        <div className="mt-1.5 flex items-center justify-between">
          <p
            id="reason-helper"
            className="text-sm text-gray-500 dark:text-gray-400"
          >
            Share any symptoms, concerns, or questions you have
          </p>
          <p
            id="char-count"
            className={cn(
              "text-sm",
              remainingChars < 50
                ? "text-error-600 dark:text-error-400 font-medium"
                : "text-gray-500 dark:text-gray-400"
            )}
          >
            {remainingChars} / {maxLength}
          </p>
        </div>
      </div>

      {/* Navigation Buttons */}
      <div className="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-800">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <div className="flex gap-3">
          {!localReason.trim() && (
            <Button variant="ghost" onClick={handleSkip}>
              Skip
            </Button>
          )}
          <Button variant="primary" onClick={handleNext} className="min-w-[120px]">
            Next
          </Button>
        </div>
      </div>
    </div>
  );
}
