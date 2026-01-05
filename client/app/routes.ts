import { type RouteConfig, index, route, layout } from "@react-router/dev/routes";

export default [
  // Public routes (no layout wrapper)
  index("routes/home.tsx"),
  route("login", "routes/login.tsx"),
  route("register", "routes/register.tsx"),

  // Protected routes (wrapped with MainLayout)
  layout("routes/layout.tsx", [
    route("dashboard", "routes/dashboard.tsx"),
    route("doctors", "routes/doctors.tsx"),
    route("doctors/:id", "routes/doctor-detail.$id.tsx"),
    route("doctors/:id/book", "routes/doctors.$id.book.tsx"),
    route("appointments", "routes/appointments.tsx"),
    route("appointments/:id", "routes/appointments.$id.tsx"),
    route("payments", "routes/payments.tsx"),
    route("profile", "routes/profile.tsx"),
    route("settings", "routes/settings.tsx"),
  ]),

  // Video consultation (full-screen, no layout)
  route("video/:id", "routes/video.$id.tsx"),
] satisfies RouteConfig;
