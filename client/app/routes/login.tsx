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
 * Login form validation schema
 */
const loginSchema = z.object({
  email: z.string().min(1, "Email is required").email("Please enter a valid email address"),
  password: z
    .string()
    .min(1, "Password is required")
    .min(6, "Password must be at least 6 characters"),
});

type LoginFormData = z.infer<typeof loginSchema>;

/**
 * Login Page Component
 *
 * Responsive login form with:
 * - Email/password validation using Zod
 * - TanStack Query mutation for API call
 * - Toast notifications for feedback
 * - Automatic redirect on success
 */
export default function LoginPage() {
  const navigate = useNavigate();
  const login = useAuthStore((state) => state.login);

  // Form setup with Zod validation
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });

  // Login mutation
  const loginMutation = useMutation({
    mutationFn: authApi.login,
    onSuccess: (data) => {
      // Store user and token in Zustand
      login(data.user, data.token);
      toast.success(`Welcome back, ${data.user.first_name}!`);
      navigate("/dashboard");
    },
    onError: (error: Error & { response?: { data?: { message?: string } } }) => {
      const message =
        error.response?.data?.message || "Invalid email or password. Please try again.";
      toast.error(message);
    },
  });

  const onSubmit = (data: LoginFormData) => {
    loginMutation.mutate(data);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950 px-4 py-8 sm:px-6 lg:px-8">
      <div className="w-full max-w-md">
        {/* Logo/Brand */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-primary-600 dark:text-primary-400">MediConnect</h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">Healthcare management platform</p>
        </div>

        <Card padding="lg">
          <CardHeader>
            <CardTitle as="h2">Sign in to your account</CardTitle>
          </CardHeader>

          <CardContent>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
              {/* Email Field */}
              <Input
                label="Email address"
                type="email"
                placeholder="you@example.com"
                autoComplete="email"
                error={errors.email?.message}
                disabled={loginMutation.isPending}
                {...register("email")}
              />

              {/* Password Field */}
              <Input
                label="Password"
                type="password"
                placeholder="Enter your password"
                autoComplete="current-password"
                error={errors.password?.message}
                disabled={loginMutation.isPending}
                {...register("password")}
              />

              {/* Submit Button */}
              <Button
                type="submit"
                fullWidth
                isLoading={loginMutation.isPending}
                loadingText="Signing in"
              >
                Sign in
              </Button>
            </form>

            {/* Register Link */}
            <div className="mt-6 text-center">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Don't have an account?{" "}
                <Link
                  to="/register"
                  className="font-medium text-primary-600 hover:text-primary-500 dark:text-primary-400 dark:hover:text-primary-300 transition-colors"
                >
                  Create one now
                </Link>
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Footer */}
        <p className="mt-8 text-center text-xs text-gray-500 dark:text-gray-500">
          By signing in, you agree to our Terms of Service and Privacy Policy.
        </p>
      </div>
    </div>
  );
}
