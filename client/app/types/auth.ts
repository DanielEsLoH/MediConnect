/**
 * Authentication TypeScript Types
 * Defines interfaces for user data, auth requests, and responses.
 */

/**
 * Medical history information for a user
 */
export interface MedicalHistory {
  blood_type?: string;
  allergies?: string[];
  chronic_conditions?: string[];
  current_medications?: string[];
}

/**
 * User entity returned from the API
 */
export interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  role: string;
  phone_number?: string;
  date_of_birth?: string;
  address?: string;
  emergency_contact_name?: string;
  emergency_contact_phone?: string;
  medical_history?: MedicalHistory;
  created_at?: string;
  updated_at?: string;
}

/**
 * Profile update request payload (partial user data)
 */
export interface UpdateProfileRequest {
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  date_of_birth?: string;
  address?: string;
  emergency_contact_name?: string;
  emergency_contact_phone?: string;
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
  phone_number: string;
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
