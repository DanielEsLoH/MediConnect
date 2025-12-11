import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation } from "@tanstack/react-query";
import { Link, useNavigate } from "react-router";
import toast from "react-hot-toast";

import { authApi } from "~/features/auth/api/auth-api";
import { useAuthStore } from "~/store/useAuthStore";
import { Button, Input, Card, CardHeader, CardTitle, CardContent } from "~/components/ui";

/**
 * Registration form validation schema
 */
const registerSchema = z
  .object({
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
    email: z.string().min(1, "Email is required").email("Please enter a valid email address"),
    phone_number: z
      .string()
      .min(1, "Phone number is required")
      .regex(/^[\d\s\-+()]+$/, "Please enter a valid phone number"),
    date_of_birth: z.string().min(1, "Date of birth is required"),
    password: z
      .string()
      .min(1, "Password is required")
      .min(8, "Password must be at least 8 characters")
      .regex(
        /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
        "Password must contain at least one uppercase letter, one lowercase letter, and one number"
      ),
    password_confirmation: z.string().min(1, "Please confirm your password"),
  })
  .refine((data) => data.password === data.password_confirmation, {
    message: "Passwords do not match",
    path: ["password_confirmation"],
  });

type RegisterFormData = z.infer<typeof registerSchema>;

/**
 * Register Page Component
 *
 * Responsive registration form with:
 * - Multi-field validation using Zod
 * - Password confirmation matching
 * - Grid layout (2 columns on desktop, 1 on mobile)
 * - TanStack Query mutation for API call
 * - Auto-login after successful registration
 */
export default function RegisterPage() {
  const navigate = useNavigate();
  const login = useAuthStore((state) => state.login);

  // Form setup with Zod validation
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      first_name: "",
      last_name: "",
      email: "",
      phone_number: "",
      date_of_birth: "",
      password: "",
      password_confirmation: "",
    },
  });

  // Register mutation
  const registerMutation = useMutation({
    mutationFn: authApi.register,
    onSuccess: (data) => {
      // Auto-login after registration
      login(data.user, data.token);
      toast.success("Account created successfully! Welcome to MediConnect.");
      navigate("/dashboard");
    },
    onError: (
      error: Error & {
        response?: { data?: { message?: string; errors?: Record<string, string[]> } };
      }
    ) => {
      const errorData = error.response?.data;
      if (errorData?.errors) {
        // Handle validation errors from API
        const firstError = Object.values(errorData.errors)[0];
        toast.error(firstError?.[0] || "Registration failed. Please check your information.");
      } else {
        toast.error(errorData?.message || "Registration failed. Please try again.");
      }
    },
  });

  const onSubmit = (data: RegisterFormData) => {
    registerMutation.mutate(data);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950 px-4 py-8 sm:px-6 lg:px-8">
      <div className="w-full max-w-2xl">
        {/* Logo/Brand */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-primary-600 dark:text-primary-400">MediConnect</h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">Healthcare management platform</p>
        </div>

        <Card padding="lg">
          <CardHeader>
            <CardTitle as="h2">Create your account</CardTitle>
            <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
              Join MediConnect to manage your healthcare needs
            </p>
          </CardHeader>

          <CardContent>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
              {/* Name Fields - 2 columns on desktop */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="First name"
                  type="text"
                  placeholder="John"
                  autoComplete="given-name"
                  error={errors.first_name?.message}
                  disabled={registerMutation.isPending}
                  {...register("first_name")}
                />
                <Input
                  label="Last name"
                  type="text"
                  placeholder="Doe"
                  autoComplete="family-name"
                  error={errors.last_name?.message}
                  disabled={registerMutation.isPending}
                  {...register("last_name")}
                />
              </div>

              {/* Email Field */}
              <Input
                label="Email address"
                type="email"
                placeholder="you@example.com"
                autoComplete="email"
                error={errors.email?.message}
                disabled={registerMutation.isPending}
                {...register("email")}
              />

              {/* Phone and DOB - 2 columns on desktop */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="Phone number"
                  type="tel"
                  placeholder="(555) 123-4567"
                  autoComplete="tel"
                  error={errors.phone_number?.message}
                  disabled={registerMutation.isPending}
                  {...register("phone_number")}
                />
                <Input
                  label="Date of birth"
                  type="date"
                  autoComplete="bday"
                  error={errors.date_of_birth?.message}
                  disabled={registerMutation.isPending}
                  {...register("date_of_birth")}
                />
              </div>

              {/* Password Fields - 2 columns on desktop */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="Password"
                  type="password"
                  placeholder="Create a password"
                  autoComplete="new-password"
                  error={errors.password?.message}
                  disabled={registerMutation.isPending}
                  helperText={!errors.password ? "Min 8 chars, 1 uppercase, 1 number" : undefined}
                  {...register("password")}
                />
                <Input
                  label="Confirm password"
                  type="password"
                  placeholder="Confirm your password"
                  autoComplete="new-password"
                  error={errors.password_confirmation?.message}
                  disabled={registerMutation.isPending}
                  {...register("password_confirmation")}
                />
              </div>

              {/* Submit Button */}
              <Button
                type="submit"
                fullWidth
                isLoading={registerMutation.isPending}
                loadingText="Creating account"
              >
                Create account
              </Button>
            </form>

            {/* Login Link */}
            <div className="mt-6 text-center">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Already have an account?{" "}
                <Link
                  to="/login"
                  className="font-medium text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                >
                  Sign in
                </Link>
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Footer */}
        <p className="mt-8 text-center text-xs text-gray-500 dark:text-gray-500">
          By creating an account, you agree to our Terms of Service and Privacy Policy.
        </p>
      </div>
    </div>
  );
}
