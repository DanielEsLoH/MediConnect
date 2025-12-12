import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

import type { User, UpdateProfileRequest } from "~/types/auth";
import { Button, Input, Card, CardHeader, CardTitle, CardContent } from "~/components/ui";

/**
 * Profile form validation schema
 */
const profileSchema = z.object({
  first_name: z
    .string()
    .min(1, "First name is required")
    .min(2, "First name must be at least 2 characters")
    .max(50, "First name must be less than 50 characters"),
  last_name: z
    .string()
    .min(1, "Last name is required")
    .min(2, "Last name must be at least 2 characters")
    .max(50, "Last name must be less than 50 characters"),
  phone_number: z
    .string()
    .min(1, "Phone number is required")
    .regex(/^[\d\s\-+()]*$/, "Please enter a valid phone number")
    .optional()
    .or(z.literal("")),
  date_of_birth: z.string().optional().or(z.literal("")),
  address: z.string().max(200, "Address must be less than 200 characters").optional().or(z.literal("")),
  emergency_contact_name: z
    .string()
    .max(100, "Emergency contact name must be less than 100 characters")
    .optional()
    .or(z.literal("")),
  emergency_contact_phone: z
    .string()
    .regex(/^[\d\s\-+()]*$/, "Please enter a valid phone number")
    .optional()
    .or(z.literal("")),
});

type ProfileFormData = z.infer<typeof profileSchema>;

interface ProfileFormProps {
  /** Current user data to populate the form */
  user: User;
  /** Callback when form is submitted */
  onSubmit: (data: UpdateProfileRequest) => void;
  /** Whether the form is currently submitting */
  isSubmitting?: boolean;
}

/**
 * ProfileForm Component
 *
 * Editable form for user profile information using React Hook Form with Zod validation.
 * Fields include:
 * - First name, Last name (required)
 * - Phone number
 * - Date of birth
 * - Address
 * - Emergency contact name and phone
 *
 * Features:
 * - Real-time validation with helpful error messages
 * - Mobile-responsive grid layout
 * - Disabled state during submission
 * - Pre-populated with current user data
 *
 * @example
 * <ProfileForm
 *   user={currentUser}
 *   onSubmit={handleUpdateProfile}
 *   isSubmitting={mutation.isPending}
 * />
 */
export function ProfileForm({ user, onSubmit, isSubmitting = false }: ProfileFormProps) {
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<ProfileFormData>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      first_name: user.first_name || "",
      last_name: user.last_name || "",
      phone_number: user.phone_number || "",
      date_of_birth: user.date_of_birth || "",
      address: user.address || "",
      emergency_contact_name: user.emergency_contact_name || "",
      emergency_contact_phone: user.emergency_contact_phone || "",
    },
  });

  const handleFormSubmit = (data: ProfileFormData) => {
    // Only send fields that have values (filter out empty strings)
    const updateData: UpdateProfileRequest = {};

    if (data.first_name) updateData.first_name = data.first_name;
    if (data.last_name) updateData.last_name = data.last_name;
    if (data.phone_number) updateData.phone_number = data.phone_number;
    if (data.date_of_birth) updateData.date_of_birth = data.date_of_birth;
    if (data.address) updateData.address = data.address;
    if (data.emergency_contact_name) updateData.emergency_contact_name = data.emergency_contact_name;
    if (data.emergency_contact_phone) updateData.emergency_contact_phone = data.emergency_contact_phone;

    onSubmit(updateData);
  };

  return (
    <Card padding="lg">
      <CardHeader>
        <CardTitle as="h3">Personal Information</CardTitle>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Update your personal details and contact information.
        </p>
      </CardHeader>

      <CardContent>
        <form onSubmit={handleSubmit(handleFormSubmit)} className="space-y-5">
          {/* Name Fields - 2 columns on desktop */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              label="First name"
              type="text"
              placeholder="John"
              autoComplete="given-name"
              error={errors.first_name?.message}
              disabled={isSubmitting}
              required
              {...register("first_name")}
            />
            <Input
              label="Last name"
              type="text"
              placeholder="Doe"
              autoComplete="family-name"
              error={errors.last_name?.message}
              disabled={isSubmitting}
              required
              {...register("last_name")}
            />
          </div>

          {/* Phone and DOB - 2 columns on desktop */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              label="Phone number"
              type="tel"
              placeholder="(555) 123-4567"
              autoComplete="tel"
              error={errors.phone_number?.message}
              disabled={isSubmitting}
              {...register("phone_number")}
            />
            <Input
              label="Date of birth"
              type="date"
              autoComplete="bday"
              error={errors.date_of_birth?.message}
              disabled={isSubmitting}
              {...register("date_of_birth")}
            />
          </div>

          {/* Address - Full width */}
          <Input
            label="Address"
            type="text"
            placeholder="123 Main St, City, State 12345"
            autoComplete="street-address"
            error={errors.address?.message}
            disabled={isSubmitting}
            {...register("address")}
          />

          {/* Emergency Contact Section */}
          <div className="pt-4 border-t border-gray-200 dark:border-gray-700">
            <h4 className="text-sm font-medium text-gray-900 dark:text-gray-100 mb-4">
              Emergency Contact
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Input
                label="Contact name"
                type="text"
                placeholder="Jane Doe"
                error={errors.emergency_contact_name?.message}
                disabled={isSubmitting}
                {...register("emergency_contact_name")}
              />
              <Input
                label="Contact phone"
                type="tel"
                placeholder="(555) 987-6543"
                error={errors.emergency_contact_phone?.message}
                disabled={isSubmitting}
                {...register("emergency_contact_phone")}
              />
            </div>
          </div>

          {/* Submit Button */}
          <div className="pt-4">
            <Button
              type="submit"
              fullWidth
              isLoading={isSubmitting}
              loadingText="Saving changes"
              disabled={!isDirty || isSubmitting}
            >
              Save Changes
            </Button>
            {!isDirty && (
              <p className="mt-2 text-xs text-center text-gray-500 dark:text-gray-400">
                Make changes to enable the save button
              </p>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
