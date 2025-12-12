import { useState, useCallback, useEffect } from "react";
import { useBookingStore } from "../../store/bookingStore";
import { useAuthStore } from "~/store/useAuthStore";
import { Button, Input } from "~/components/ui";
import { cn } from "~/lib/utils";
import type { PersonalData } from "../../types";

export interface PersonalDataStepProps {
  /** Callback when step is completed */
  onNext: () => void;
  /** Callback to go back */
  onBack: () => void;
}

/**
 * Validate email format.
 */
function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

/**
 * Validate phone number format (basic check).
 */
function isValidPhone(phone: string): boolean {
  // Remove common formatting characters
  const cleaned = phone.replace(/[\s\-()]/g, "");
  // Check if it's 10-15 digits
  return /^\d{10,15}$/.test(cleaned);
}

/**
 * Personal Data Confirmation Step (Step 4)
 *
 * Allows user to:
 * - Review their personal information
 * - Edit name, email, and phone if needed
 * - Validate all fields before proceeding
 *
 * Data is pre-filled from the authenticated user's profile.
 */
export function PersonalDataStep({ onNext, onBack }: PersonalDataStepProps) {
  const { personalData, setPersonalData } = useBookingStore();
  const { user } = useAuthStore();

  // Initialize from stored data or user profile
  const [formData, setFormData] = useState<PersonalData>(() => {
    if (personalData) {
      return personalData;
    }
    // Pre-fill from user profile
    if (user) {
      return {
        full_name: `${user.first_name} ${user.last_name}`.trim(),
        email: user.email,
        phone: user.phone_number || "",
      };
    }
    return {
      full_name: "",
      email: "",
      phone: "",
    };
  });

  const [errors, setErrors] = useState<Partial<Record<keyof PersonalData, string>>>({});
  const [touched, setTouched] = useState<Partial<Record<keyof PersonalData, boolean>>>({});

  // Validate form
  const validateForm = useCallback((): boolean => {
    const newErrors: Partial<Record<keyof PersonalData, string>> = {};

    // Full name validation
    if (!formData.full_name.trim()) {
      newErrors.full_name = "Full name is required";
    } else if (formData.full_name.trim().length < 2) {
      newErrors.full_name = "Full name must be at least 2 characters";
    }

    // Email validation
    if (!formData.email.trim()) {
      newErrors.email = "Email is required";
    } else if (!isValidEmail(formData.email)) {
      newErrors.email = "Please enter a valid email address";
    }

    // Phone validation
    if (!formData.phone.trim()) {
      newErrors.phone = "Phone number is required";
    } else if (!isValidPhone(formData.phone)) {
      newErrors.phone = "Please enter a valid phone number (10-15 digits)";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }, [formData]);

  // Handle field change
  const handleChange = useCallback(
    (field: keyof PersonalData, value: string) => {
      setFormData((prev) => ({ ...prev, [field]: value }));
      // Clear error for this field
      if (errors[field]) {
        setErrors((prev) => {
          const { [field]: _, ...rest } = prev;
          return rest;
        });
      }
    },
    [errors]
  );

  // Handle field blur
  const handleBlur = useCallback(
    (field: keyof PersonalData) => {
      setTouched((prev) => ({ ...prev, [field]: true }));
    },
    []
  );

  // Handle next button click
  const handleNext = useCallback(() => {
    // Mark all fields as touched
    setTouched({
      full_name: true,
      email: true,
      phone: true,
    });

    // Validate
    if (!validateForm()) {
      return;
    }

    // Save to store
    setPersonalData(formData);

    // Proceed to next step
    onNext();
  }, [formData, validateForm, setPersonalData, onNext]);

  const isFormValid =
    formData.full_name.trim() &&
    formData.email.trim() &&
    formData.phone.trim() &&
    isValidEmail(formData.email) &&
    isValidPhone(formData.phone);

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
            Confirm Your Details
          </p>
          <p className="text-sm text-blue-700 dark:text-blue-300 mt-1">
            Please review and confirm your contact information. This will be used for
            appointment reminders and notifications.
          </p>
        </div>
      </div>

      {/* Form Fields */}
      <div className="space-y-5">
        {/* Full Name */}
        <Input
          label="Full Name"
          placeholder="John Doe"
          value={formData.full_name}
          onChange={(e) => handleChange("full_name", e.target.value)}
          onBlur={() => handleBlur("full_name")}
          error={touched.full_name ? errors.full_name : undefined}
          required
          autoComplete="name"
        />

        {/* Email */}
        <Input
          label="Email Address"
          type="email"
          placeholder="john.doe@example.com"
          value={formData.email}
          onChange={(e) => handleChange("email", e.target.value)}
          onBlur={() => handleBlur("email")}
          error={touched.email ? errors.email : undefined}
          required
          autoComplete="email"
        />

        {/* Phone */}
        <Input
          label="Phone Number"
          type="tel"
          placeholder="+1 (555) 123-4567"
          value={formData.phone}
          onChange={(e) => handleChange("phone", e.target.value)}
          onBlur={() => handleBlur("phone")}
          error={touched.phone ? errors.phone : undefined}
          required
          autoComplete="tel"
          helperText="We'll use this number to contact you about your appointment"
        />
      </div>

      {/* Data Source Info (if pre-filled) */}
      {user && (
        <div className="flex items-center gap-2 text-sm text-gray-500 dark:text-gray-400">
          <svg
            className="w-4 h-4"
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
          <span>Pre-filled from your profile</span>
        </div>
      )}

      {/* Navigation Buttons */}
      <div className="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-800">
        <Button variant="outline" onClick={onBack}>
          Back
        </Button>
        <Button
          variant="primary"
          onClick={handleNext}
          disabled={!isFormValid}
          className="min-w-[120px]"
        >
          Next
        </Button>
      </div>

      {/* Validation Help */}
      {!isFormValid && Object.keys(touched).length > 0 && (
        <p className="text-center text-sm text-error-600 dark:text-error-400">
          Please fix the errors above to continue
        </p>
      )}
    </div>
  );
}
