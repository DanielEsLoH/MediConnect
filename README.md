# MediConnect

Medical appointment management platform built with microservices architecture.

## Architecture

- **Backend**: Ruby on Rails 8.1.1 microservices
- **Frontend**: React 18+ with TypeScript
- **Mobile**: React Native with Expo
- **Infrastructure**: Docker, PostgreSQL, Redis, RabbitMQ

## Services

- API Gateway (Port 3000)
- Users Service (Port 3001)
- Doctors Service (Port 3002)
- Appointments Service (Port 3003)
- Notifications Service (Port 3004)
- Payments Service (Port 3005)

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Ruby 3.4.7
- Node.js 20+
- PostgreSQL 18.1
- Redis 7+
- RabbitMQ 3+

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd MediConnect
```

2. Start infrastructure services:
```bash
docker-compose up -d
```

3. Setup backend services:
```bash
./scripts/setup.sh
```

4. Start development servers:
```bash
# API Gateway
cd services/api_gateway && bin/rails s -p 3000

# Users Service
cd services/users_service && bin/rails s -p 3001

# Continue for other services...
```

5. Start frontend:
```bash
cd frontend && npm run dev
```

6. Start mobile app:
```bash
cd mobile && npx expo start
```

## Development

See comprehensive development plan in `plans/` directory for detailed implementation guide.

## Project Status

**Phase**: Phase 2 - Backend Microservices (Week 7-8)
**Status**: 60% Complete - Payments Service Completed ✅
**Last Updated**: December 4, 2025

### Completed ✅
- [x] Phase 0: Project Setup & Docker Infrastructure
- [x] Phase 1: Core Infrastructure (API Gateway, Authentication)
- [x] Phase 2 (Partial): Backend Microservices
  - [x] Users Service - User management & authentication
  - [x] Doctors Service - Doctor profiles, schedules, reviews
  - [x] Appointments Service - Appointment lifecycle management
  - [x] Notifications Service - Multi-channel notifications
  - [x] **Payments Service - Stripe integration** ✅ **COMPLETED Dec 4, 2025**

### In Progress 🚧
- [ ] Service-to-Service Communication (HttpClient, ServiceRegistry, RabbitMQ Consumers)
- [ ] Comprehensive Testing (RSpec, >80% coverage)
- [ ] API Documentation (Swagger/OpenAPI)

### Next Milestone 🎯
**Step 2: Service-to-Service Communication** - Implement HttpClient, ServiceRegistry, and RabbitMQ event consumers across all services to enable inter-service communication and event-driven workflows.

## Technology Stack

### Backend
- Ruby on Rails 8.1.1 (API mode)
- PostgreSQL 18.1
- Redis 7+
- RabbitMQ 3.x
- Sidekiq
- JWT Authentication
- Stripe API

### Frontend
- React 18+ with TypeScript
- Vite
- TailwindCSS
- TanStack Query
- Zustand
- React Router 7.9.6

### Mobile
- React Native 0.73+
- Expo SDK 50+
- NativeWind
- Expo Router

### Infrastructure
- Docker & Docker Compose
- Kubernetes (production)
- GitHub Actions (CI/CD)

## License

MIT
