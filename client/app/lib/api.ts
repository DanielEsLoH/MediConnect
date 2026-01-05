import axios from 'axios';
import { useAuthStore } from '~/store/useAuthStore';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1';

/**
 * Configured Axios instance for API communication.
 * Includes JWT authentication and standardized error handling.
 */
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * Request interceptor: Attach JWT token to all requests.
 */
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('auth_token');

    // Debug logging for auth issues
    if (import.meta.env.DEV) {
      console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`);
      console.log('[API Request] Token present:', !!token);
    }

    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

/**
 * Flag to prevent multiple simultaneous logout redirects
 */
let isLoggingOut = false;

/**
 * Response interceptor: Handle API errors consistently.
 * - Logs errors for debugging
 * - Handles 401 Unauthorized by clearing auth state and redirecting to login
 * - Distinguishes between network errors and API errors
 */
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      // Server responded with error status
      const { config, status, data } = error.response;
      console.error('API Error:', status, data);

      // Debug: Log full details for 401 errors
      if (import.meta.env.DEV && status === 401) {
        console.error('[API 401 Debug] URL:', config?.url);
        console.error('[API 401 Debug] Method:', config?.method);
        console.error('[API 401 Debug] Auth header sent:', config?.headers?.Authorization ? 'Yes' : 'No');
        console.error('[API 401 Debug] Response:', data);
      }

      // Handle 401 Unauthorized - clear ALL auth state and redirect to login
      // Skip logout for login/register endpoints to avoid clearing state during auth
      const isAuthEndpoint = config?.url?.includes('/auth/login') || config?.url?.includes('/users');
      if (status === 401 && !isLoggingOut && !isAuthEndpoint) {
        isLoggingOut = true;

        // Clear Zustand store state (this also clears localStorage token)
        useAuthStore.getState().logout();

        // Only redirect if not already on login page to avoid infinite loops
        if (!window.location.pathname.includes('/login')) {
          // Use a small delay to ensure state is cleared before redirect
          setTimeout(() => {
            window.location.href = '/login';
            isLoggingOut = false;
          }, 100);
        } else {
          isLoggingOut = false;
        }
      }
    } else if (error.request) {
      // Request made but no response received (network error)
      console.error('Network Error:', error.request);
    } else {
      // Error in request configuration
      console.error('Error:', error.message);
    }
    return Promise.reject(error);
  }
);

export default api;
