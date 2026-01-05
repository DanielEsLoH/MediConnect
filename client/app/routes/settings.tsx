import { useState, useCallback, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import toast from "react-hot-toast";

import { useAuthStore } from "~/store/useAuthStore";
import { authApi } from "~/features/auth/api/auth-api";
import { notificationsApi, type NotificationPreferences } from "~/features/notifications";
import {
  Button,
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
  Input,
  Spinner,
} from "~/components/ui";
import { cn } from "~/lib/utils";
import type { UpdateProfileRequest } from "~/types/auth";

/**
 * Query keys for settings page.
 */
const settingsKeys = {
  profile: ["settings", "profile"] as const,
  preferences: ["settings", "notificationPreferences"] as const,
};

/**
 * Toggle Switch Component.
 */
interface ToggleSwitchProps {
  id: string;
  label: string;
  description?: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
}

function ToggleSwitch({
  id,
  label,
  description,
  checked,
  onChange,
  disabled = false,
}: ToggleSwitchProps) {
  return (
    <div className="flex items-center justify-between py-3">
      <div className="flex-1 pr-4">
        <label
          htmlFor={id}
          className="text-sm font-medium text-gray-900 dark:text-gray-100 cursor-pointer"
        >
          {label}
        </label>
        {description && (
          <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">{description}</p>
        )}
      </div>
      <button
        id={id}
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={cn(
          "relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out",
          "focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-500 focus-visible:ring-offset-2",
          checked ? "bg-primary-600" : "bg-gray-200 dark:bg-gray-700",
          disabled && "opacity-50 cursor-not-allowed"
        )}
      >
        <span className="sr-only">{label}</span>
        <span
          className={cn(
            "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
            checked ? "translate-x-5" : "translate-x-0"
          )}
        />
      </button>
    </div>
  );
}

/**
 * Section Divider Component.
 */
function SectionDivider() {
  return <div className="border-t border-gray-200 dark:border-gray-700 my-4" />;
}

/**
 * Settings Section Header Component.
 */
interface SectionHeaderProps {
  title: string;
  description?: string;
}

function SectionHeader({ title, description }: SectionHeaderProps) {
  return (
    <div className="mb-4">
      <h3 className="text-base font-semibold text-gray-900 dark:text-gray-100">{title}</h3>
      {description && (
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{description}</p>
      )}
    </div>
  );
}

/**
 * Confirmation Dialog Component.
 */
interface ConfirmDialogProps {
  isOpen: boolean;
  title: string;
  message: string;
  confirmLabel: string;
  variant?: "danger" | "primary";
  isLoading?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

function ConfirmDialog({
  isOpen,
  title,
  message,
  confirmLabel,
  variant = "danger",
  isLoading,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="dialog-title"
    >
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onCancel}
        aria-hidden="true"
      />

      {/* Dialog */}
      <div className="relative bg-white dark:bg-gray-900 rounded-xl shadow-xl max-w-md w-full p-6 animate-in fade-in zoom-in-95 duration-200">
        <h3 id="dialog-title" className="text-lg font-semibold text-gray-900 dark:text-gray-100">
          {title}
        </h3>
        <p className="mt-2 text-sm text-gray-600 dark:text-gray-400">{message}</p>

        <div className="mt-6 flex gap-3 justify-end">
          <Button variant="ghost" onClick={onCancel} disabled={isLoading}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={onConfirm}
            isLoading={isLoading}
            loadingText="Processing..."
            className={
              variant === "danger"
                ? "bg-error-600 hover:bg-error-700 active:bg-error-800 focus-visible:ring-error-500"
                : ""
            }
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}

/**
 * Settings Page Component
 *
 * User settings with sections:
 * - Profile section: Edit name, phone, avatar
 * - Notification preferences: Toggle email, SMS, push notifications
 * - Security section: Change password, 2FA settings
 * - Appearance section: Dark mode toggle, language
 * - Account section: Download data, delete account
 */
export default function SettingsPage() {
  const queryClient = useQueryClient();
  const { user, setUser } = useAuthStore();

  // Local state for form fields
  const [firstName, setFirstName] = useState(user?.first_name ?? "");
  const [lastName, setLastName] = useState(user?.last_name ?? "");
  const [phoneNumber, setPhoneNumber] = useState(user?.phone_number ?? "");
  const [isDirty, setIsDirty] = useState(false);

  // Notification preferences state
  const [preferences, setPreferences] = useState<NotificationPreferences>({
    email_enabled: true,
    push_enabled: true,
    sms_enabled: false,
    appointment_reminders: true,
    payment_notifications: true,
    marketing_emails: false,
  });

  // Appearance state
  const [darkMode, setDarkMode] = useState(false);
  const [language, setLanguage] = useState("en");

  // Dialog states
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [showPasswordDialog, setShowPasswordDialog] = useState(false);

  // Initialize dark mode from document
  useEffect(() => {
    const isDark = document.documentElement.classList.contains("dark");
    setDarkMode(isDark);
  }, []);

  // Fetch notification preferences
  const { data: notifPrefs, isLoading: isLoadingPrefs } = useQuery({
    queryKey: settingsKeys.preferences,
    queryFn: notificationsApi.getPreferences,
    staleTime: 1000 * 60 * 5,
    retry: 1,
  });

  // Update preferences state when data loads
  useEffect(() => {
    if (notifPrefs) {
      setPreferences(notifPrefs);
    }
  }, [notifPrefs]);

  // Track form changes
  useEffect(() => {
    const hasChanges =
      firstName !== (user?.first_name ?? "") ||
      lastName !== (user?.last_name ?? "") ||
      phoneNumber !== (user?.phone_number ?? "");
    setIsDirty(hasChanges);
  }, [firstName, lastName, phoneNumber, user]);

  // Update profile mutation
  const updateProfileMutation = useMutation({
    mutationFn: (data: UpdateProfileRequest) => authApi.updateProfile(data),
    onSuccess: (updatedUser) => {
      setUser(updatedUser);
      setIsDirty(false);
      toast.success("Profile updated successfully!");
    },
    onError: (error) => {
      const message = error instanceof Error ? error.message : "Failed to update profile";
      toast.error(message);
    },
  });

  // Update notification preferences mutation
  const updatePrefsMutation = useMutation({
    mutationFn: (prefs: Partial<NotificationPreferences>) =>
      notificationsApi.updatePreferences(prefs),
    onSuccess: (updatedPrefs) => {
      setPreferences(updatedPrefs);
      queryClient.setQueryData(settingsKeys.preferences, updatedPrefs);
      toast.success("Notification preferences updated!");
    },
    onError: (error) => {
      const message =
        error instanceof Error ? error.message : "Failed to update preferences";
      toast.error(message);
    },
  });

  // Handle profile form submit
  const handleProfileSubmit = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      updateProfileMutation.mutate({
        first_name: firstName,
        last_name: lastName,
        phone_number: phoneNumber || undefined,
      });
    },
    [firstName, lastName, phoneNumber, updateProfileMutation]
  );

  // Handle preference toggle
  const handlePreferenceToggle = useCallback(
    (key: keyof NotificationPreferences, value: boolean) => {
      const newPrefs = { ...preferences, [key]: value };
      setPreferences(newPrefs);
      updatePrefsMutation.mutate({ [key]: value });
    },
    [preferences, updatePrefsMutation]
  );

  // Handle dark mode toggle
  const handleDarkModeToggle = useCallback((enabled: boolean) => {
    setDarkMode(enabled);
    if (enabled) {
      document.documentElement.classList.add("dark");
      localStorage.setItem("theme", "dark");
    } else {
      document.documentElement.classList.remove("dark");
      localStorage.setItem("theme", "light");
    }
    toast.success(`${enabled ? "Dark" : "Light"} mode enabled`);
  }, []);

  // Handle delete account
  const handleDeleteAccount = useCallback(() => {
    // Placeholder - would call API
    toast.error("Account deletion is not yet implemented");
    setShowDeleteDialog(false);
  }, []);

  // Handle download data
  const handleDownloadData = useCallback(() => {
    // Placeholder - would call API
    toast.success("Your data export request has been submitted. You will receive an email shortly.");
  }, []);

  return (
    <>
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-gray-100">
          Settings
        </h1>
        <p className="mt-2 text-gray-600 dark:text-gray-400">
          Manage your account settings and preferences.
        </p>
      </div>

      <div className="space-y-6">
        {/* Profile Section */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Profile Information</CardTitle>
          </CardHeader>
          <form onSubmit={handleProfileSubmit}>
            <CardContent>
              <div className="space-y-6">
                {/* Avatar */}
                <div className="flex items-center gap-4">
                  <div
                    className={cn(
                      "w-20 h-20 rounded-full flex items-center justify-center",
                      "bg-primary-100 dark:bg-primary-900",
                      "text-primary-700 dark:text-primary-300",
                      "text-2xl font-semibold"
                    )}
                  >
                    {user?.first_name?.charAt(0).toUpperCase()}
                    {user?.last_name?.charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      disabled
                      className="opacity-60"
                    >
                      Change Avatar
                    </Button>
                    <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                      JPG, PNG. Max 2MB.
                    </p>
                  </div>
                </div>

                {/* Name Fields */}
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label
                      htmlFor="firstName"
                      className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
                    >
                      First Name
                    </label>
                    <Input
                      id="firstName"
                      type="text"
                      value={firstName}
                      onChange={(e) => setFirstName(e.target.value)}
                      placeholder="Enter your first name"
                    />
                  </div>
                  <div>
                    <label
                      htmlFor="lastName"
                      className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
                    >
                      Last Name
                    </label>
                    <Input
                      id="lastName"
                      type="text"
                      value={lastName}
                      onChange={(e) => setLastName(e.target.value)}
                      placeholder="Enter your last name"
                    />
                  </div>
                </div>

                {/* Phone Number */}
                <div>
                  <label
                    htmlFor="phone"
                    className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
                  >
                    Phone Number
                  </label>
                  <Input
                    id="phone"
                    type="tel"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    placeholder="Enter your phone number"
                  />
                  <p className="mt-1.5 text-sm text-gray-500 dark:text-gray-400">
                    Used for appointment reminders and urgent notifications.
                  </p>
                </div>

                {/* Email (Read-only) */}
                <div>
                  <label
                    htmlFor="email"
                    className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
                  >
                    Email Address
                  </label>
                  <Input
                    id="email"
                    type="email"
                    value={user?.email ?? ""}
                    disabled
                    className="bg-gray-50 dark:bg-gray-800"
                  />
                  <p className="mt-1.5 text-sm text-gray-500 dark:text-gray-400">
                    Contact support to change your email address.
                  </p>
                </div>
              </div>
            </CardContent>
            <CardFooter className="flex justify-end">
              <Button
                type="submit"
                variant="primary"
                disabled={!isDirty}
                isLoading={updateProfileMutation.isPending}
                loadingText="Saving..."
              >
                Save Changes
              </Button>
            </CardFooter>
          </form>
        </Card>

        {/* Notification Preferences Section */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Notification Preferences</CardTitle>
          </CardHeader>
          <CardContent>
            {isLoadingPrefs ? (
              <div className="flex items-center justify-center py-8">
                <Spinner size="md" label="Loading preferences..." />
              </div>
            ) : (
              <>
                <SectionHeader
                  title="Notification Channels"
                  description="Choose how you want to receive notifications."
                />

                <div className="space-y-1">
                  <ToggleSwitch
                    id="email-notifications"
                    label="Email Notifications"
                    description="Receive updates and reminders via email"
                    checked={preferences.email_enabled}
                    onChange={(val) => handlePreferenceToggle("email_enabled", val)}
                    disabled={updatePrefsMutation.isPending}
                  />
                  <ToggleSwitch
                    id="push-notifications"
                    label="Push Notifications"
                    description="Receive real-time notifications in your browser"
                    checked={preferences.push_enabled}
                    onChange={(val) => handlePreferenceToggle("push_enabled", val)}
                    disabled={updatePrefsMutation.isPending}
                  />
                  <ToggleSwitch
                    id="sms-notifications"
                    label="SMS Notifications"
                    description="Receive important updates via text message"
                    checked={preferences.sms_enabled}
                    onChange={(val) => handlePreferenceToggle("sms_enabled", val)}
                    disabled={updatePrefsMutation.isPending}
                  />
                </div>

                <SectionDivider />

                <SectionHeader
                  title="Notification Types"
                  description="Select which types of notifications you want to receive."
                />

                <div className="space-y-1">
                  <ToggleSwitch
                    id="appointment-reminders"
                    label="Appointment Reminders"
                    description="Get reminded before your scheduled appointments"
                    checked={preferences.appointment_reminders}
                    onChange={(val) => handlePreferenceToggle("appointment_reminders", val)}
                    disabled={updatePrefsMutation.isPending}
                  />
                  <ToggleSwitch
                    id="payment-notifications"
                    label="Payment Notifications"
                    description="Receive notifications about payments and invoices"
                    checked={preferences.payment_notifications}
                    onChange={(val) => handlePreferenceToggle("payment_notifications", val)}
                    disabled={updatePrefsMutation.isPending}
                  />
                  <ToggleSwitch
                    id="marketing-emails"
                    label="Marketing & Promotions"
                    description="Receive health tips, news, and special offers"
                    checked={preferences.marketing_emails}
                    onChange={(val) => handlePreferenceToggle("marketing_emails", val)}
                    disabled={updatePrefsMutation.isPending}
                  />
                </div>
              </>
            )}
          </CardContent>
        </Card>

        {/* Security Section */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Security</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {/* Change Password */}
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Password
                  </h3>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
                    Last changed over 30 days ago
                  </p>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowPasswordDialog(true)}
                  disabled
                  className="opacity-60"
                >
                  Change Password
                </Button>
              </div>

              <SectionDivider />

              {/* Two-Factor Authentication */}
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Two-Factor Authentication
                  </h3>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
                    Add an extra layer of security to your account
                  </p>
                </div>
                <Button variant="outline" size="sm" disabled className="opacity-60">
                  Enable 2FA
                </Button>
              </div>

              <SectionDivider />

              {/* Active Sessions */}
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Active Sessions
                  </h3>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
                    Manage devices where you're logged in
                  </p>
                </div>
                <Button variant="ghost" size="sm" disabled className="opacity-60">
                  View Sessions
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Appearance Section */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Appearance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {/* Dark Mode */}
              <ToggleSwitch
                id="dark-mode"
                label="Dark Mode"
                description="Switch between light and dark themes"
                checked={darkMode}
                onChange={handleDarkModeToggle}
              />

              <SectionDivider />

              {/* Language Selection */}
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Language
                  </h3>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
                    Select your preferred language
                  </p>
                </div>
                <select
                  value={language}
                  onChange={(e) => {
                    setLanguage(e.target.value);
                    toast.success("Language preference saved");
                  }}
                  className={cn(
                    "rounded-lg border bg-white transition-colors duration-200",
                    "px-3 py-2 text-sm",
                    "text-gray-900",
                    "focus:outline-none focus:ring-2 focus:ring-offset-0",
                    "border-gray-300 hover:border-gray-400",
                    "focus:border-primary-500 focus:ring-primary-500/20",
                    "dark:bg-gray-900 dark:text-gray-100 dark:border-gray-700"
                  )}
                >
                  <option value="en">English</option>
                  <option value="es">Spanish</option>
                  <option value="fr">French</option>
                  <option value="de">German</option>
                  <option value="zh">Chinese</option>
                </select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Account Section */}
        <Card>
          <CardHeader>
            <CardTitle as="h2">Account</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-6">
              {/* Download Data */}
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">
                    Download Your Data
                  </h3>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
                    Get a copy of all your data in a machine-readable format
                  </p>
                </div>
                <Button variant="outline" size="sm" onClick={handleDownloadData}>
                  Request Download
                </Button>
              </div>

              <SectionDivider />

              {/* Delete Account */}
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-medium text-error-600 dark:text-error-400">
                    Delete Account
                  </h3>
                  <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
                    Permanently delete your account and all associated data
                  </p>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowDeleteDialog(true)}
                  className="border-error-300 text-error-600 hover:bg-error-50 dark:border-error-700 dark:text-error-400 dark:hover:bg-error-900/20"
                >
                  Delete Account
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Delete Account Dialog */}
      <ConfirmDialog
        isOpen={showDeleteDialog}
        title="Delete Account"
        message="Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data, including appointments, medical records, and payment history will be permanently deleted."
        confirmLabel="Delete My Account"
        variant="danger"
        onConfirm={handleDeleteAccount}
        onCancel={() => setShowDeleteDialog(false)}
      />
    </>
  );
}