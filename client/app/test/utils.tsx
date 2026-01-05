import type { ReactElement, ReactNode } from "react";
import { render } from "@testing-library/react";
import type { RenderOptions, RenderResult } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter } from "react-router";

/**
 * Creates a fresh QueryClient for testing
 */
function createTestQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        gcTime: 0,
        staleTime: 0,
      },
      mutations: {
        retry: false,
      },
    },
  });
}

/**
 * Props for test wrapper providers
 */
interface WrapperProps {
  children: ReactNode;
}

/**
 * Creates a wrapper with all providers for testing
 */
function createWrapper(queryClient?: QueryClient) {
  const client = queryClient || createTestQueryClient();

  return function Wrapper({ children }: WrapperProps) {
    return (
      <QueryClientProvider client={client}>
        <BrowserRouter>{children}</BrowserRouter>
      </QueryClientProvider>
    );
  };
}

/**
 * Custom render function with all providers
 */
export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, "wrapper"> & {
    queryClient?: QueryClient;
  }
): RenderResult & { queryClient: QueryClient } {
  const { queryClient, ...renderOptions } = options || {};
  const client = queryClient || createTestQueryClient();
  const Wrapper = createWrapper(client);

  return {
    ...render(ui, { wrapper: Wrapper, ...renderOptions }),
    queryClient: client,
  };
}

/**
 * Wait for a condition to be true
 */
export async function waitFor(
  condition: () => boolean,
  timeout = 1000
): Promise<void> {
  const start = Date.now();
  while (!condition()) {
    if (Date.now() - start > timeout) {
      throw new Error("waitFor timeout");
    }
    await new Promise((r) => setTimeout(r, 10));
  }
}

/**
 * Create a mock notification for testing
 */
export function createMockNotification(overrides = {}) {
  return {
    id: "test-notification-1",
    user_id: "user-1",
    notification_type: "appointment_reminder" as const,
    title: "Appointment Reminder",
    message: "Your appointment is in 1 hour",
    data: {},
    channels: ["in_app" as const],
    read_at: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    ...overrides,
  };
}

/**
 * Create a mock review for testing
 */
export function createMockReview(overrides = {}) {
  return {
    id: "test-review-1",
    doctor_id: "doctor-1",
    patient_id: "patient-1",
    appointment_id: "appointment-1",
    rating: 5,
    title: "Great experience",
    comment: "Dr. Smith was very helpful and professional.",
    verified: true,
    helpful_count: 10,
    not_helpful_count: 1,
    patient_name: "John Doe",
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    ...overrides,
  };
}

/**
 * Create a mock user for testing
 */
export function createMockUser(overrides = {}) {
  return {
    id: "test-user-1",
    email: "test@example.com",
    first_name: "John",
    last_name: "Doe",
    role: "patient" as const,
    phone: "+1234567890",
    avatar_url: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    ...overrides,
  };
}

/**
 * Create a mock appointment for testing
 */
export function createMockAppointment(overrides = {}) {
  return {
    id: "test-appointment-1",
    patient_id: "patient-1",
    doctor_id: "doctor-1",
    scheduled_time: new Date(Date.now() + 86400000).toISOString(), // Tomorrow
    duration_minutes: 30,
    status: "confirmed" as const,
    consultation_type: "video" as const,
    reason: "Annual checkup",
    notes: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    doctor: {
      id: "doctor-1",
      first_name: "Dr. Sarah",
      last_name: "Smith",
      specialty: "General Practice",
      avatar_url: null,
    },
    ...overrides,
  };
}

// Re-export everything from testing-library
export * from "@testing-library/react";
export { default as userEvent } from "@testing-library/user-event";