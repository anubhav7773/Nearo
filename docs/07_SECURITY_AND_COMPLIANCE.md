# Nearo Security & Privacy Compliance Architecture (v1.0)

Document Version: 1.0.0
Standard: India DPDP Act (Digital Personal Data Protection) & OWASP Mobile/API Top 10
Ecosystem: asiverticals.me / nearo.asiverticals.me

---

## 1. Zero-Knowledge Resident Privacy Architecture

### 1.1 Mobile Number & Identity Isolation
* **Phone Number Ingestion:** Phone numbers captured during authentication are encrypted at rest using AES-256-GCM.
* **Public Serialization Guard:** The `phone_number` field must NEVER be exposed in public API models or client-side JSON feeds.
* **Neighborhood Aliasing:** Every user profile is surfaced publicly as an immutable alias (`alias_name`). Real identities and database primary keys (`UUID`) are decoupled from external lookups.

### 1.2 Geolocation Jitter & Anti-Triangulation Engine
To prevent malicious physical tracking or triangulation of neighborhood residents:
* **Storage vs. Presentation Separation:** Exact GPS coordinates (`ST_Point(lon, lat)`) are stored in `user_locations` strictly for radius bounding calculations (`ST_DWithin`).
* **Gaussian Jitter on Public Posts:** Every public post coordinate returned via `/posts/feed` has an automated pseudo-random 75–125 meter spatial jitter applied at query serialization:

```python
# Core Jitter Math (services/geo_service.py)
import random
import math

def apply_coordinate_jitter(lat: float, lon: float, radius_meters: float = 100.0) -> tuple[float, float]:
    r = radius_meters / 111300.0  # Approximate conversion: meters to degrees
    u = random.random()
    v = random.random()
    w = r * math.sqrt(u)
    t = 2 * math.pi * v
    jitter_lat = w * math.cos(t)
    jitter_lon = (w * math.sin(t)) / math.cos(math.radians(lat))
    return lat + jitter_lat, lon + jitter_lon
2. Authentication, Token Guards & Session Management2.1 Cryptographic StandardsAccess Tokens: Signed via RS256 or HS256 with a strict 60-minute expiry.Refresh Tokens: High-entropy 256-bit cryptographically secure strings stored hashed (SHA-256) with a 30-day sliding expiry.Mobile Storage: Flutter client must persist authentication tokens strictly in platform-secure hardware keystores (flutter_secure_storage using Android Keystore and iOS Keychain).2.2 Token Revocation & BlocklistingBlacklisted JWT tokens (upon logout or tier change) are immediately pushed to Redis key jwt_blocklist:{token_jti} with a TTL matching the token remaining life.3. Threat Mitigation & Rate Limiting (Redis Token Bucket)Route / ActionRate Limit ThresholdPenalty ActionPOST /auth/otp/send3 requests / 10 mins per IP & Phone15-minute temporary IP blockPOST /auth/otp/verify5 failed attempts per session IDInvalidate OTP sessionPOST /posts5 posts / hour per User UUIDHTTP 429 Too Many RequestsPOST /sos/broadcast1 active SOS per User / 5-min cooldownRate-limit with UI alertGET /posts/feed60 requests / minute per UserHTTP 429 Too Many Requests4. Data Protection, Governance & India DPDP Compliance4.1 Right to Erasure (Account & Data Purge)Nearo provides a 1-click account deletion endpoint (DELETE /api/v1/auth/account).Triggering erasure immediately executes:Cascade deletion of user record and linked geofence coordinates in user_locations.Anonymization of community posts (setting author_id to a generic system placeholder [Deleted Resident]).Immediate revocation of all active JWT sessions in Redis.4.2 Automated Content Moderation & Abuse FiltersKeyword Filter: Post creation pipelines reject payloads containing hate speech, communal slurs, and predatory contact harvesting.Crowdsourced Moderation: Any post receiving 3 distinct resident flags (FLAG_SPAM, FLAG_HARASSMENT, FLAG_FAKE_ALERT) is automatically moved to quarantine_status pending admin review.5. Network & Edge Security DirectivesHTTPS Enforcement: TLS 1.3 enforced across all subdomains on Cloudflare.CORS Whitelist: API Gateway only allows requests originating from trusted subdomains (*.asiverticals.me) and native mobile client headers.SQL Injection Shield: Explicit use of SQLAlchemy 2.0 type-safe expressions and parameterized queries for all PostGIS spatial filters.