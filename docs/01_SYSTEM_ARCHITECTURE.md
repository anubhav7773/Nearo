# Nearo System Architecture

## 1. Executive Summary & Overview
Nearo is a privacy-first, hyperlocal community and civic SOS mobile platform operating under the parent domain `asiverticals.me` (subdomain: `nearo.asiverticals.me`). The system connects residents within a strict 1–3 km geographic radius to facilitate verified neighborhood interactions, civic scam alerts, emergency SOS dispatching, and non-intrusive local commerce.

---

## 2. High-Level Architecture Diagram

+-----------------------------------------------------------------------+
|                       Flutter Client (Android / iOS)                 |
+-----------------------------------+-----------------------------------+
|
| HTTPS / WSS (Cloudflare Edge)
v
+-----------------------------------+-----------------------------------+
|               FastAPI Async Application Gateway (v1)                  |
|  +---------------------+  +--------------------+  +-----------------+ |
|  | Auth & Token Guard  |  | Geospatial Engine  |  | SOS Dispatcher  | |
|  +---------------------+  +--------------------+  +-----------------+ |
+------------------+-------------------+-------------------+------------+
|                   |                   |
v                   v                   v
+------------------+----+     +--------+---------+     +---+------------+
|  PostgreSQL 16 +     |     |   Redis 7 Cache  |     | Cloudflare R2  |
|  PostGIS Extension   |     |   & PubSub       |     | (Media / Docs) |
+-----------------------+     +------------------+     +----------------+


---

## 3. Subsystem Breakdown

### 3.1 Mobile Client (Flutter)
* **Architecture:** Feature-First Clean Architecture (`core/`, `features/auth`, `features/feed`, `features/sos`, `features/profile`).
* **State Management:** BLoC / Cubit for predictable state transitions and offline stream subscriptions.
* **Networking:** Dio client with automated JWT refresh interceptors and exponential backoff retry policies.
* **Geofencing:** Periodic low-power background location pings using standard GPS fused location providers.

### 3.2 Backend Services (FastAPI)
* **Runtime:** Python 3.11+ running asynchronously under Uvicorn workers behind a reverse proxy.
* **Modularity:** API versioning (`/api/v1`) with decoupled services for Geo-filtering, Push Alerts, Subscriptions, and Ad injection.
* **Validation:** Strict runtime data parsing with Pydantic v2 schemas and centralized exception handling.

### 3.3 Database & Spatial Engine (PostgreSQL / PostGIS)
* **Spatial Schema:** All geospatial data stored using EPSG:4326 geometry/geography primitives (`ST_Point`).
* **Indexing:** Spatial R-Tree indexes (`GIST`) configured over coordinate columns for sub-millisecond radius calculations.
* **Connection Pooling:** Asyncpg connection pool managed via SQLAlchemy 2.0 Async Session engine.

### 3.4 Caching & Real-time PubSub (Redis)
* **Session Storage:** Revoked JWT blocklist and OTP rate-limiting state.
* **PubSub Broker:** WebSocket room management for active SOS alert broadcasting across nearby connected clients.

---

## 4. Hyperlocal Geospatial Indexing & Routing
* **Radius Boundary:** Standard feed queries strictly enforce bounding calculations:
  ```sql
  ST_DWithin(
      user_locations.geom,
      ST_SetSRID(ST_MakePoint(:user_lon, :user_lat), 4326)::geography,
      :radius_meters
  )
Geofence Partitions: Default active radius is locked to 1,500 meters (expandable to 3,000 meters in low-density suburban zones).

Caching Strategy: Frequently fetched regional feeds are cached in Redis with a 60-second TTL keyed by geohash precision 6 (~1.2 km²).

5. Civic SOS Alert & Dispatch Engine
Trigger Mechanism: Instant client-side SOS activation triggers high-priority WebSocket events and asynchronous Firebase Cloud Messaging (FCM) push alerts.

Dispatch Rules:

Active users within a 1.5 km radius receive immediate critical-level push notifications.

Zero advertisements or promotional cards are rendered in the active SOS channel.

Real-time GPS breadcrumbs are broadcasted via Redis PubSub until the SOS state is resolved.

6. Local Ad & Hyperlocal Sponsorship Engine
Ad Placement Strategy:

Contextual sponsored business cards are injected natively into the feed at a fixed cadence (1 ad per 7 community posts).

Priority listing placement in local search directory queries.

Ad Exclusion Rules:

Users with active Resident Pro subscriptions (tier = 'pro') receive zero injected feed ads.

SOS emergency feed and verified civic scam alerts are permanently excluded from ad injections.

7. Security, Privacy & Anonymity Considerations
PII Protection: Real phone numbers and exact home coordinates are never exposed over public API payloads.

Display Aliases: Users interact via verified community aliases while internal identity stays mapped to immutable system IDs.

Coordinate Jittering: Public-facing post locations apply a randomized 100-meter Gaussian jitter to prevent physical triangulation.

Rate Limiting: IP-level and token-level request throttling enforced via Redis token-bucket algorithms.

8. Scalability & Disaster Recovery
Stateless API: FastAPI instances run containerized and horizontally scalable behind Cloudflare load balancers.

Data Backups: Automated daily PostgreSQL WAL snapshots with 30-day point-in-time recovery (PITR).

Graceful Degradation: When location services are disabled, client falls back to cached Pin Code boundary snapshots.