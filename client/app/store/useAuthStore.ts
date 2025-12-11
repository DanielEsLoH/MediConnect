import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import type { User } from "~/types/auth";

/**
 * Auth store state interface
 */
interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
}

/**
 * Auth store actions interface
 */
interface AuthActions {
  login: (user: User, token: string) => void;
  logout: () => void;
  setUser: (user: User) => void;
}

type AuthStore = AuthState & AuthActions;

/**
 * Authentication store with localStorage persistence.
 * Manages user session, token storage, and authentication state.
 *
 * @example
 * const { user, isAuthenticated, login, logout } = useAuthStore();
 */
export const useAuthStore = create<AuthStore>()(
  persist(
    (set) => ({
      // Initial state
      user: null,
      token: null,
      isAuthenticated: false,

      /**
       * Login action: Set user data and token, mark as authenticated.
       * Also saves token to localStorage for API interceptor access.
       */
      login: (user: User, token: string) => {
        // Save token separately for API interceptor
        localStorage.setItem("auth_token", token);
        set({
          user,
          token,
          isAuthenticated: true,
        });
      },

      /**
       * Logout action: Clear all auth state and remove token.
       */
      logout: () => {
        localStorage.removeItem("auth_token");
        set({
          user: null,
          token: null,
          isAuthenticated: false,
        });
      },

      /**
       * Update user data without changing token/auth status.
       */
      setUser: (user: User) => {
        set({ user });
      },
    }),
    {
      name: "mediconnect-auth",
      storage: createJSONStorage(() => localStorage),
      // Only persist these fields
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
      // On rehydration, ensure token is synced
      onRehydrateStorage: () => (state) => {
        if (state?.token) {
          localStorage.setItem("auth_token", state.token);
        }
      },
    }
  )
);
