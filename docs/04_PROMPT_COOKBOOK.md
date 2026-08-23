# Nearo Antigravity Prompt Cookbook

Use these pre-engineered modular prompts inside Antigravity/Cursor. Each prompt is isolated to minimize token usage and prevent hallucinated code.

---

## 1. Backend Core & Database Setup
```text
Context: Read `docs/01_SYSTEM_ARCHITECTURE.md` and `docs/02_DATABASE_SCHEMA.sql`.
Task: Implement the core database engine and configuration in `backend/app/core/`.
Requirements:
1. Setup SQLAlchemy 2.0 Async engine with `asyncpg` in `database.py`.
2. Configure Pydantic v2 BaseSettings in `config.py` loading from `.env`.
3. Implement JWT access & refresh token utilities with password hashing in `security.py`.
4. Output only clean, working code without conversational filler.
2. Geospatial Radius Feed Service
Plaintext
Context: Read `docs/02_DATABASE_SCHEMA.sql` and `docs/03_API_CONTRACT.md`.
Task: Implement `backend/app/services/geo_service.py` and `backend/app/api/v1/endpoints/feed.py`.
Requirements:
1. Write raw async PostGIS query using `ST_DWithin` to fetch posts within the user's preferred radius.
2. Inject a sponsored native ad card after every 6th community post using `backend/app/services/ad_engine.py`.
3. Skip ad injection entirely if the requesting user has `tier = 'pro_resident'`.
4. Return response strictly matching Section 3.1 in `03_API_CONTRACT.md`.
3. Civic SOS Realtime Broadcast Engine
Plaintext
Context: Read `docs/02_DATABASE_SCHEMA.sql` and `docs/03_API_CONTRACT.md`.
Task: Implement `backend/app/services/alert_service.py` and `backend/app/api/v1/endpoints/sos.py`.
Requirements:
1. Endpoint `POST /sos/broadcast` inserts new `sos_events` record with PostGIS `ST_MakePoint`.
2. Query all active `user_locations` within a 1,500m radius using PostGIS.
3. Broadcast the SOS payload via Redis PubSub channel `sos_channel_{pincode}`.
4. Ensure zero promotional/ad data is attached to this pipeline.
4. Flutter Clean Architecture State (Radius Feed)
Plaintext
Context: Read `docs/03_API_CONTRACT.md` (Section 3.1).
Task: Implement the Flutter Feed module inside `mobile/lib/features/feed/`.
Requirements:
1. Create `FeedModel` parsing both `community_post` and `native_ad` items.
2. Build `FeedBloc` handling `FetchRadiusFeed`, `FeedLoading`, `FeedLoaded`, and `FeedError`.
3. Create `FeedCardWidget` for standard posts and `NativeAdCardWidget` with WhatsApp redirect button.
4. Use Flutter Clean Architecture standards.
5. Flutter SOS Alert Screen with Live Ping
Plaintext
Context: Read `docs/03_API_CONTRACT.md` (Section 4.1).
Task: Implement the SOS presentation layer inside `mobile/lib/features/sos/`.
Requirements:
1. Single-tap large emergency trigger button with vibration haptic feedback.
2. Emergency type picker (Security / Medical / Scam Alert).
3. Geolocation provider capturing current GPS coordinates prior to dispatch.
4. Red alert theme with clear, accessible UI.