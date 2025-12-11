/**
 * Authentication TypeScript Types
 * Defines interfaces for user data, auth requests, and responses.
 */

/**
 * User entity returned from the API
 */
export interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  role: string;
  phone?: string;
  date_of_birth?: string;
  created_at?: string;
  updated_at?: string;
}

/**
 * Login request payload
 */
export interface LoginRequest {
  email: string;
  password: string;
}

/**
 * Registration request payload
 */
export interface RegisterRequest {
  email: string;
  password: string;
  password_confirmation: string;
  first_name: string;
  last_name: string;
  phone: string;
  date_of_birth: string;
}

/**
 * Authentication response from login/register endpoints
 */
export interface AuthResponse {
  token: string;
  user: User;
}

/**
 * API error response structure
 */
export interface AuthError {
  message: string;
  errors?: Record<string, string[]>;
}
