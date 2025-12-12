import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { authApi } from "~/features/auth/api/auth-api";
import { useAuthStore } from "~/store/useAuthStore";
import type { User, UpdateProfileRequest } from "~/types/auth";
import { Spinner, Card } from "~/components/ui";
import { ProfileHeader, ProfileForm, MedicalHistoryCard } from "~/components/profile";

/**
 * Query keys for profile data.
 */
const profileKeys = {
  all: ["profile"] as const,
  current: () => [...profileKeys.all, "current"] as const,
};

/**
 * Profile Page Component
 *
 * User profile page where users can view and edit their personal information
 * and view their medical history.
 *
 * Features:
 * - 2-column layout on desktop (profile left, medical history right)
 * - Stacked layout on mobile
 * - Fetches current user data with useQuery
 * - Updates profile with useMutation
 * - Optimistic updates for better UX
 * - Loading and error states
 * - Toast notifications for feedback
 *
 * @example
 * Route: /profile
 */
export default function ProfilePage() {
  const queryClient = useQueryClient();
  const { user: storeUser, setUser } = useAuthStore();

  // Fetch current user data
  const {
    data: user,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: profileKeys.current(),
    queryFn: authApi.getCurrentUser,
    // Use store user as initial data for instant display
    initialData: storeUser || undefined,
    staleTime: 1000 * 60 * 5, // Consider data fresh for 5 minutes
    retry: 2,
  });

  // Update profile mutation with optimistic updates
  const updateProfileMutation = useMutation({
    mutationFn: authApi.updateProfile,
    onMutate: async (newData: UpdateProfileRequest) => {
      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey: profileKeys.current() });

      // Snapshot the previous value
      const previousUser = queryClient.getQueryData<User>(profileKeys.current());

      // Optimistically update to the new value
      if (previousUser) {
        const optimisticUser: User = {
          ...previousUser,
          ...newData,
        };
        queryClient.setQueryData<User>(profileKeys.current(), optimisticUser);
        // Also update the auth store for immediate UI feedback
        setUser(optimisticUser);
      }

      return { previousUser };
    },
    onSuccess: (updatedUser) => {
      // Update the cache with the server response
      queryClient.setQueryData<User>(profileKeys.current(), updatedUser);
      // Update the auth store
      setUser(updatedUser);
      toast.success("Profile updated successfully!");
    },
    onError: (err, _newData, context) => {
      // Revert optimistic update on error
      if (context?.previousUser) {
        queryClient.setQueryData<User>(profileKeys.current(), context.previousUser);
        setUser(context.previousUser);
      }

      const errorMessage =
        err instanceof Error
          ? err.message
          : "Failed to update profile. Please try again.";

      // Check for API error response
      const apiError = err as Error & {
        response?: { data?: { message?: string; errors?: Record<string, string[]> } };
      };

      if (apiError.response?.data?.errors) {
        const firstError = Object.values(apiError.response.data.errors)[0];
        toast.error(firstError?.[0] || errorMessage);
      } else if (apiError.response?.data?.message) {
        toast.error(apiError.response.data.message);
      } else {
        toast.error(errorMessage);
      }
    },
    onSettled: () => {
      // Invalidate to ensure we have fresh data
      queryClient.invalidateQueries({ queryKey: profileKeys.current() });
    },
  });

  // Handle profile form submission
  const handleUpdateProfile = (data: UpdateProfileRequest) => {
    updateProfileMutation.mutate(data);
  };

  // Loading state
  if (isLoading && !user) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Your Profile
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Manage your personal information and medical history.
          </p>
        </div>

        {/* Loading State */}
        <div className="flex items-center justify-center py-16">
          <Spinner size="lg" label="Loading profile..." />
        </div>
      </>
    );
  }

  // Error state
  if (isError && !user) {
    return (
      <>
        {/* Page Header */}
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Your Profile
          </h1>
          <p className="mt-2 text-gray-600 dark:text-gray-400">
            Manage your personal information and medical history.
          </p>
        </div>

        {/* Error State */}
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
            Unable to Load Profile
          </h2>
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-400 max-w-md">
            {error instanceof Error
              ? error.message
              : "An error occurred while loading your profile."}
          </p>
          <button
            type="button"
            onClick={() => refetch()}
            className="mt-6 px-4 py-2 bg-primary-600 text-white rounded-lg font-medium hover:bg-primary-700 transition-colors"
          >
            Try Again
          </button>
        </div>
      </>
    );
  }

  // No user data available (shouldn't happen if authenticated)
  if (!user) {
    return (
      <>
        <div className="mb-8">
          <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
            Your Profile
          </h1>
        </div>
        <Card padding="lg">
          <p className="text-center text-gray-500 dark:text-gray-400">
            Unable to load profile data. Please try logging in again.
          </p>
        </Card>
      </>
    );
  }

  return (
    <>
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Your Profile
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Manage your personal information and medical history.
        </p>
      </div>

      {/* Main Content - 2 columns on desktop, stacked on mobile */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8">
        {/* Left Column - Profile Header and Form */}
        <div className="lg:col-span-2 space-y-6">
          {/* Profile Header Card */}
          <Card padding="none">
            <ProfileHeader user={user} />
          </Card>

          {/* Profile Form */}
          <ProfileForm
            user={user}
            onSubmit={handleUpdateProfile}
            isSubmitting={updateProfileMutation.isPending}
          />
        </div>

        {/* Right Column - Medical History */}
        <div className="lg:col-span-1">
          <MedicalHistoryCard medicalHistory={user.medical_history} />
        </div>
      </div>
    </>
  );
}
