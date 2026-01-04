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
- PostgreSQL 16+
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

**Overall Completion**: ~60% (Accurate as of December 12, 2025)
**Current Phase**: Web Frontend Development - Critical Features ⚠️
**Last Updated**: December 12, 2025

### Component Status
| Component | Status | Completion |
|-----------|--------|------------|
| Backend Services | ✅ Production-Ready | 95% |
| Web Frontend | ⚠️ Basic Pages Complete | 60% |
| Mobile App | ❌ Not Started | 0% |
| Testing Coverage | ⚠️ Partial | 15% |
| Deployment | ❌ Not Started | 0% |

### Completed ✅
- [x] Phase 0: Project Setup & Docker Infrastructure
- [x] Phase 1: Core Infrastructure (API Gateway, Authentication)
- [x] Phase 2: Backend Microservices (All 6 services)
  - [x] Users Service - User management & authentication
  - [x] Doctors Service - Doctor profiles, schedules, reviews
  - [x] Appointments Service - Appointment lifecycle management
  - [x] Notifications Service - Multi-channel notifications
  - [x] Payments Service - Stripe integration
  - [x] Service-to-Service Communication (HttpClient, ServiceRegistry, RabbitMQ)
- [x] Phase 3 (Partial): Web Frontend - Basic Pages
  - [x] Authentication (Login, Register)
  - [x] Doctors List & Detail
  - [x] Simple Booking Form
  - [x] Appointments List
  - [x] User Profile
  - [x] Payments Integration

### Critical Missing Features ❌
- [ ] **Multi-step booking stepper** (6 steps) - HIGHEST PRIORITY
- [ ] **Real-time notifications** (NotificationBell + WebSocket)
- [ ] **Review/rating system UI** (StarRating, ReviewForm, ReviewList)
- [ ] **Video consultation** (LiveKit integration)
- [ ] **Missing pages** (Home, Appointment Detail, Settings, Video)
- [ ] **Common components** (Modal, Badge, Avatar, DatePicker, Pagination)
- [ ] **Custom hooks** (useDebounce, useLocalStorage, useWebSocket, etc.)
- [ ] **Comprehensive testing** (>80% coverage target)
- [ ] **CI/CD pipeline** (GitHub Actions)
- [ ] **Production deployment**

### Next Milestone 🎯
**Web MVP Launch** (2-3 weeks) - Complete critical missing features to achieve 90% web frontend completion and launch functional MVP for user testing.

**Detailed Roadmap**: See `.claude/IMPLEMENTATION_ROADMAP.md`

## Technology Stack

### Backend
- Ruby on Rails 8.1.1 (API mode)
- PostgreSQL 16+
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
