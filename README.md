# Nearo — Hyperlocal Community & Civic SOS Platform

[![Backend CI / CD](https://github.com/asiverticals/nearo/actions/workflows/backend_ci.yml/badge.svg)](https://github.com/asiverticals/nearo/actions/workflows/backend_ci.yml)
[![Flutter Mobile CI](https://github.com/asiverticals/nearo/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/asiverticals/nearo/actions/workflows/flutter_ci.yml)

> **Live Subdomain Gateway**: [https://nearo.asiverticals.me](https://nearo.asiverticals.me)  
> **API Version**: `v1` (`/api/v1`)  
> **Ecosystem**: ASI Verticals (`asiverticals.me`)

Nearo is a privacy-first, zero-knowledge hyperlocal community platform connecting verified residents within a strict 1–3 km geographic radius for civic scam alerts, emergency SOS dispatching, neighborhood feeds, and non-intrusive local commerce.

---

## 🏗️ Repository Architecture

```
nearo/
├── docs/                      # Architectural specifications & technical contracts
│   ├── 01_SYSTEM_ARCHITECTURE.md
│   ├── 02_DATABASE_SCHEMA.sql
│   ├── 03_API_CONTRACT.md
│   ├── 04_PROMPT_COOKBOOK.md
│   ├── 05_DEPLOYMENT_GUIDE.md
│   ├── 06_UI_UX_SPECIFICATION.md
│   └── 07_SECURITY_AND_COMPLIANCE.md
├── backend/                   # FastAPI + Async Python 3.11 Geospatial Backend
│   ├── app/
│   │   ├── api/v1/            # API endpoints (Auth, Feed, SOS, Ads, Subscriptions, Location)
│   │   ├── core/              # Config (Pydantic v2), Security (PyJWT/bcrypt), Database (SQLAlchemy 2.0 asyncpg), Redis
│   │   ├── db/                # Schema initializer (init_db.py) & mock demo seeder (seed_demo_data.py)
│   │   ├── models/            # PostGIS models (User, Post, SOSEvent, LocalAd, Subscription)
│   │   ├── schemas/           # Pydantic v2 request/response schemas
│   │   ├── services/          # GeoService (ST_DWithin, Gaussian jitter), AdEngine, AlertService
│   │   └── main.py            # FastAPI lifespan, CORS middleware, exception handlers
│   ├── tests/                 # Automated test suite (test_auth.py, test_geo_feed.py, test_sos.py)
│   ├── Dockerfile             # Multi-stage production container (non-root nearouser)
│   └── requirements.txt       # Pinned dependencies
├── mobile/                    # Flutter 3.x Clean Architecture Mobile Client
│   ├── lib/
│   │   ├── core/              # AppColors, ApiEndpoints, SecureStorage, ApiClient (Dio), AppTheme
│   │   ├── features/          # Auth, Feed, SOS, Profile (BLoC state management)
│   │   └── main.dart          # MultiBlocProvider, Auth gate & 4-tab Navigation
│   ├── test/                  # Flutter widget & unit tests (feed_widget_test.dart, sos_trigger_test.dart)
│   └── pubspec.yaml
├── .github/workflows/         # Automated CI/CD pipelines (backend_ci.yml, flutter_ci.yml)
├── docker-compose.yml         # Orchestrates app, PostGIS 16 (db), and Redis 7 (redis)
└── README.md
```

---

## 🚀 One-Command Quick Start (Docker Compose)

### 1. Launch the Entire Stack
Run from the repository root:
```bash
docker compose up -d --build
```

This starts:
- **FastAPI Backend Gateway**: `http://localhost:8000` (Swagger UI: `http://localhost:8000/api/v1/docs`)
- **PostgreSQL 16 + PostGIS 3.4**: `localhost:5432` (`nearo_db`)
- **Redis 7 In-Memory Broker**: `localhost:6379`

### 2. Verify Services & Container Health
```bash
docker compose ps
```

---

## 🗄️ Database Initialization & Mock Data Seeding

### Automatic Schema Setup
To initialize PostGIS extensions, enum types, declarative tables, and spatial GIST indexes:
```bash
cd backend
python -m app.db.init_db
```

### Seed Realistic Demo Data
Populate 5 verified residents, 10 geofenced community posts, 2 local native ads, and 1 active SOS event around Ayodhya Central (`26.7922° N, 82.1998° E`):
```bash
cd backend
python -m app.db.seed_demo_data
```

---

## 🧪 Automated Testing Suite

### Backend Pytest Suite
```bash
cd backend
pytest -v
```
Verifies:
- Mobile OTP send, OTP verify, and JWT access/refresh token lifecycle.
- PostGIS `ST_DWithin` and `ST_Distance` queries.
- Anti-triangulation 75–125m Gaussian spatial jitter (DPDP compliance).
- Native ad injection cadence (1 ad per 7 community posts) and 100% ad-free `pro_resident` tier exclusion.
- Emergency SOS dispatch and active incident lookups.

### Flutter Mobile Tests
```bash
cd mobile
flutter test
```
Verifies:
- `CommunityFeedCard` rendering, verified badges, upvote toggle callbacks.
- `SponsoredFeedCard` rendering and WhatsApp direct CTA launch.
- `SosScreen` 1.5-second long-press animated button, emergency selector, and haptic trigger dispatch.

---

## 🔒 Security & India DPDP Compliance

- **Zero-Knowledge Privacy**: Phone numbers and exact coordinates are never exposed in public feeds. Residents interact strictly via mutable neighborhood aliases.
- **Anti-Triangulation Jitter**: 75–125m Gaussian spatial jitter applied automatically at serialization.
- **Token-Bucket Rate Limiting**: Redis-backed limits on OTP (3 req/10 mins), Post creation (5/hr), and SOS broadcasts (5-min cooldown).
- **1-Click Right to Erasure**: `DELETE /api/v1/auth/account` immediately cascades user locations and revokes active JWTs.

---

## 🌐 Production Domain & Cloudflare DNS Setup

For deploying to `nearo.asiverticals.me`:
1. **Cloudflare DNS**:
   - Add **A Record**: `nearo` -> `<SERVER_PUBLIC_IP>` (Proxied / Orange Cloud).
2. **SSL/TLS Mode**: **Full (Strict)**.
3. **WebSockets**: Enabled under Cloudflare Network settings for real-time SOS alerting.
4. **Healthcheck Probe**: `curl -I https://nearo.asiverticals.me/api/v1/health` (Expected: `200 OK`).

---
© 2026 Nearo Platform — ASI Verticals.
