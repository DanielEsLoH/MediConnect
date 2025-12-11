import type { Route } from "./+types/home";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "MediConnect - Medical Appointment Platform" },
    {
      name: "description",
      content: "MediConnect - Your trusted medical appointment management platform",
    },
  ];
}

export default function Home() {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <h1 className="text-4xl font-bold text-blue-600">MediConnect</h1>
    </div>
  );
}
