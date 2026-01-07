# MediConnect

A comprehensive medical appointment management platform built with a microservices architecture. MediConnect enables patients to discover doctors, book appointments, conduct video consultations, and manage payments seamlessly.

## Features

- **Doctor Discovery** - Browse doctors by specialty, view profiles, ratings, and reviews
- **Appointment Booking** - Multi-step booking with date/time selection and payment processing
- **Video Consultations** - Real-time video calls powered by LiveKit
- **Real-time Notifications** - WebSocket-based notifications for appointment updates
- **Payment Processing** - Secure payments via Stripe integration
- **User Profiles** - Medical history, allergies, and personal information management

## Architecture

MediConnect uses a microservices architecture with an API Gateway pattern:

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client (React)                          │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway (Port 3000)                    │
│         Authentication, Routing, Rate Limiting, CORS           │
└─────────────────────────────────────────────────────────────────┘
                                 │
        ┌────────────┬───────────┼───────────┬────────────┐
        ▼            ▼           ▼           ▼            ▼
   ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌─────────┐
   │  Users  │ │ Doctors │ │Appoint-  │ │ Notif-  │ │Payments │
   │ Service │ │ Service │ │  ments   │ │ ications│ │ Service │
   │  :3001  │ │  :3002  │ │  :3003   │ │  :3004  │ │  :3005  │
   └─────────┘ └─────────┘ └──────────┘ └─────────┘ └─────────┘
        │            │           │           │            │
        └────────────┴───────────┼───────────┴────────────┘
                                 ▼
              ┌─────────────────────────────────────┐
              │   PostgreSQL  │  Redis  │ RabbitMQ │
              └─────────────────────────────────────┘
```

### Services

| Service | Port | Description |
|---------|------|-------------|
| **API Gateway** | 3000 | Request routing, JWT auth, rate limiting |
| **Users Service** | 3001 | User accounts, profiles, medical records |
| **Doctors Service** | 3002 | Doctor profiles, schedules, reviews, search |
| **Appointments Service** | 3003 | Booking, scheduling, video sessions |
| **Notifications Service** | 3004 | Multi-channel notifications, WebSocket |
| **Payments Service** | 3005 | Stripe integration, payment history |

## Technology Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| React | 19 | UI framework |
| TypeScript | 5.9 | Type safety |
| React Router | 7.10 | Routing |
| TailwindCSS | 4.1 | Styling |
| Zustand | 5.0 | State management |
| TanStack Query | 5.90 | Server state |
| LiveKit | 2.16 | Video conferencing |
| Stripe | 8.5 | Payment processing |
| Vite | 7.1 | Build tool |

### Backend
| Technology | Version | Purpose |
|------------|---------|---------|
| Ruby on Rails | 8.1.1 | API framework |
| Ruby | 3.4.7 | Language |
| PostgreSQL | 16+ | Database |
| Redis | 7+ | Caching & sessions |
| RabbitMQ | 3.x | Message broker |
| Sidekiq | 7.0 | Background jobs |
| JWT | 2.7 | Authentication |
| Stripe | 10.0 | Payments |
| LiveKit SDK | 0.7 | Video infrastructure |

### Development & Testing
| Tool | Purpose |
|------|---------|
| Docker & Docker Compose | Containerization |
| RSpec | Backend testing |
| Vitest | Frontend testing |
| SimpleCov | Code coverage |
| RuboCop | Ruby linting |
| Prettier | Code formatting |

## Getting Started

### Prerequisites

- **Docker and Docker Compose** (required)
- Node.js 20+ (for frontend development)

> Docker handles all backend services, databases, Redis, RabbitMQ, and LiveKit automatically. No need to install Ruby, PostgreSQL, or other backend dependencies locally.

### Quick Start with Docker

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd MediConnect
   ```

2. **Start the entire backend stack**
   ```bash
   cd server
   docker compose up -d
   ```

   This starts all services:
   - 6 Rails microservices (API Gateway + 5 domain services)
   - 6 PostgreSQL databases (one per service)
   - Redis (caching and sessions)
   - RabbitMQ (message broker)
   - LiveKit (video conferencing)

3. **Wait for services to be healthy** (first run takes 2-3 minutes to build)
   ```bash
   docker compose ps
   ```
   All services should show "healthy" status.

4. **Run database migrations and seed data**
   ```bash
   # Run migrations for all services
   docker compose exec api-gateway bin/rails db:migrate
   docker compose exec users-service bin/rails db:migrate
   docker compose exec doctors-service bin/rails db:migrate
   docker compose exec appointments-service bin/rails db:migrate
   docker compose exec notifications-service bin/rails db:migrate
   docker compose exec payments-service bin/rails db:migrate

   # Seed test data (optional)
   docker compose exec users-service bin/rails db:seed
   docker compose exec doctors-service bin/rails db:seed
   docker compose exec appointments-service bin/rails db:seed
   docker compose exec notifications-service bin/rails db:seed
   docker compose exec payments-service bin/rails db:seed
   ```

5. **Start the frontend**
   ```bash
   cd ../client
   npm install
   npm run dev
   ```

6. **Access the application**
   | Service | URL |
   |---------|-----|
   | Frontend | http://localhost:5173 |
   | API Gateway | http://localhost:3000 |
   | RabbitMQ Management | http://localhost:15672 (guest/guest) |

### Docker Commands Reference

```bash
# Start all services
docker compose up -d

# Start with rebuild (after Gemfile changes)
docker compose up -d --build

# View logs
docker compose logs -f                    # All services
docker compose logs -f api-gateway        # Single service

# Stop all services
docker compose down

# Stop and remove volumes (reset databases)
docker compose down -v

# Restart a single service
docker compose restart api-gateway

# Run Rails console
docker compose exec users-service bin/rails console

# Run migrations
docker compose exec api-gateway bin/rails db:migrate

# Run tests inside container
docker compose exec api-gateway bundle exec rspec

# Check service health
docker compose ps
```

### Docker Services Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                    │
├─────────────────────────────────────────────────────────────┤
│  MICROSERVICES                                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ api-gateway  │ │users-service │ │   doctors-service    │ │
│  │    :3000     │ │    :3001     │ │        :3002         │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │appointments- │ │notifications-│ │   payments-service   │ │
│  │   service    │ │   service    │ │        :3005         │ │
│  │    :3003     │ │    :3004     │ │                      │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  DATABASES (PostgreSQL 16)                                  │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐               │
│  │  :5432     │ │   :5433    │ │   :5434    │  ... :5437    │
│  │  gateway   │ │   users    │ │  doctors   │               │
│  └────────────┘ └────────────┘ └────────────┘               │
├─────────────────────────────────────────────────────────────┤
│  INFRASTRUCTURE                                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐               │
│  │   Redis    │ │  RabbitMQ  │ │  LiveKit   │               │
│  │   :6379    │ │:5672/:15672│ │   :7880    │               │
│  └────────────┘ └────────────┘ └────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

### Alternative: Running Without Docker

<details>
<summary>Click to expand manual setup instructions</summary>

If you prefer to run services locally without Docker:

**Prerequisites:**
- Ruby 3.4.7
- PostgreSQL 16+
- Redis 7+
- RabbitMQ 3.x

**Setup:**
```bash
cd server

# For each service
for service in api-gateway users-service doctors-service appointments-service notifications-service payments-service; do
  cd $service
  bundle install
  bin/rails db:create db:migrate db:seed
  cd ..
done
```

**Start services (each in a separate terminal):**
```bash
cd server/api-gateway && bin/rails s -p 3000
cd server/users-service && bin/rails s -p 3001
cd server/doctors-service && bin/rails s -p 3002
cd server/appointments-service && bin/rails s -p 3003
cd server/notifications-service && bin/rails s -p 3004
cd server/payments-service && bin/rails s -p 3005
```

</details>

### Environment Variables

Create `.env` files in each service directory. Key variables:

```bash
# Database
DATABASE_URL=postgres://user:pass@localhost:5432/service_db

# Redis
REDIS_URL=redis://localhost:6379/0

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@localhost:5672

# JWT
JWT_SECRET=your-secret-key

# Stripe (Payments Service)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...

# LiveKit (Appointments Service)
LIVEKIT_API_KEY=your-api-key
LIVEKIT_API_SECRET=your-api-secret
LIVEKIT_URL=ws://localhost:7880
```

## Development

### Running Tests

**Backend (All Services)**
```bash
cd server
./bin/test-all.sh              # Run all tests
./bin/test-all.sh --parallel   # Parallel execution
./bin/test-all.sh --service users-service  # Single service
./bin/test-all.sh --ci         # CI mode with JUnit output
```

**Frontend**
```bash
cd client
npm run test           # Watch mode
npm run test:run       # Single run
npm run test:coverage  # With coverage
```

### Code Quality

**Ruby (Backend)**
```bash
bundle exec rubocop        # Check style
bundle exec rubocop -A     # Auto-fix
bundle exec brakeman       # Security scan
```

**TypeScript (Frontend)**
```bash
npm run typecheck      # Type checking
npm run format         # Format with Prettier
npm run format:check   # Check formatting
```

### Useful Docker Commands

```bash
# Service Management
docker compose up -d                              # Start all services
docker compose down                               # Stop all services
docker compose restart api-gateway                # Restart single service
docker compose ps                                 # Check service status

# Logs
docker compose logs -f                            # All services
docker compose logs -f api-gateway users-service  # Multiple services

# Rails Commands (inside containers)
docker compose exec api-gateway bin/rails console
docker compose exec users-service bin/rails db:migrate
docker compose exec doctors-service bin/rails db:seed

# Testing
docker compose exec api-gateway bundle exec rspec
docker compose exec users-service bundle exec rspec spec/models

# Debugging
docker compose exec api-gateway bin/rails routes
docker compose exec users-service bin/rails dbconsole
```

## Project Structure

```
MediConnect/
├── client/                      # React Frontend
│   ├── app/
│   │   ├── features/           # Feature modules
│   │   │   ├── appointments/   # Appointment management
│   │   │   ├── auth/           # Authentication
│   │   │   ├── booking/        # Multi-step booking
│   │   │   ├── doctors/        # Doctor discovery
│   │   │   ├── notifications/  # Real-time notifications
│   │   │   ├── payments/       # Payment processing
│   │   │   ├── reviews/        # Doctor reviews
│   │   │   └── video/          # Video consultations
│   │   ├── components/         # Shared components
│   │   │   ├── ui/             # UI component library
│   │   │   ├── layout/         # Layout components
│   │   │   └── video/          # Video components
│   │   ├── hooks/              # Custom React hooks
│   │   ├── routes/             # Page components
│   │   ├── store/              # Zustand stores
│   │   └── lib/                # Utilities
│   └── package.json
│
├── server/                      # Rails Backend
│   ├── api-gateway/            # API Gateway
│   ├── users-service/          # User management
│   ├── doctors-service/        # Doctor profiles
│   ├── appointments-service/   # Appointments
│   ├── notifications-service/  # Notifications
│   ├── payments-service/       # Payments
│   ├── bin/
│   │   └── test-all.sh         # Test runner
│   └── docker-compose.yml      # Infrastructure
│
└── README.md
```

## API Documentation

### Authentication

All API requests (except login/register) require a JWT token:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/v1/...
```

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/login` | User login |
| POST | `/api/v1/auth/register` | User registration |
| GET | `/api/v1/doctors` | List doctors |
| GET | `/api/v1/doctors/:id` | Doctor details |
| GET | `/api/v1/appointments` | User appointments |
| POST | `/api/v1/appointments` | Create appointment |
| GET | `/api/v1/notifications` | User notifications |
| POST | `/api/v1/payments` | Create payment |

## Project Status

| Component | Status | Coverage |
|-----------|--------|----------|
| API Gateway | Production Ready | 92% |
| Users Service | Production Ready | 94% |
| Doctors Service | Production Ready | 99% |
| Appointments Service | Production Ready | 94% |
| Notifications Service | Production Ready | 96% |
| Payments Service | Production Ready | 91% |
| **Backend Overall** | **Production Ready** | **94%** |
| Web Frontend | Feature Complete | - |
| Mobile App | Not Started | - |

**Test Suite**: 2,576 tests across all services

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation
- `style:` - Code style (formatting, linting)
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

## License

MIT