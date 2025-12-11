import { MainLayout } from "~/components/layout";

/**
 * Layout Route Component
 *
 * This is the layout wrapper for all protected routes.
 * It provides the sidebar, header, and main content area.
 * Authentication is handled by MainLayout component.
 */
export default function ProtectedLayout() {
  return <MainLayout />;
}
