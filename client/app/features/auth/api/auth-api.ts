import api from "~/lib/api";
import type { AuthResponse, LoginRequest, RegisterRequest, User } from "~/types/auth";

/**
 * Authentication API service.
 * Handles all auth-related API calls: login, register, logout, and user fetch.
 */
export const authApi = {
  /**
   * Login with email and password.
   * @param credentials - User email and password
   * @returns Auth response with token and user data
   */
  login: async (credentials: LoginRequest): Promise<AuthResponse> => {
    const response = await api.post<AuthResponse>("/auth/login", credentials);
    return response.data;
  },

  /**
   * Register a new user account.
   * @param data - Registration form data
   * @returns Auth response with token and user data
   */
  register: async (data: RegisterRequest): Promise<AuthResponse> => {
    // Explicitly structure the payload to ensure all fields are in the nested user object
    const payload = {
      user: {
        email: data.email,
        password: data.password,
        password_confirmation: data.password_confirmation,
        first_name: data.first_name,
        last_name: data.last_name,
        phone_number: data.phone_number,
        date_of_birth: data.date_of_birth,
      },
    };
    const response = await api.post<AuthResponse>("/users", payload);
    return response.data;
  },

  /**
   * Get the current authenticated user.
   * Requires a valid auth token in the request headers.
   * @returns Current user data
   */
  getCurrentUser: async (): Promise<User> => {
    const response = await api.get<User>("/auth/me");
    return response.data;
  },

  /**
   * Logout the current user.
   * Invalidates the current session on the server.
   */
  logout: async (): Promise<void> => {
    await api.delete("/auth/logout");
  },
};
