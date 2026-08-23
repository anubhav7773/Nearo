# Nearo API Contract (v1)

Base URL: `https://nearo.asiverticals.me/api/v1`  
Protocol: `HTTPS / JSON`  
Authentication: `Bearer <JWT_ACCESS_TOKEN>`

---

## 1. Authentication & Onboarding

### 1.1 Send Mobile OTP
* **Endpoint:** `POST /auth/otp/send`
* **Request:**
```json
{
  "phone_number": "+919876543210"
}
Response (200 OK):

JSON
{
  "success": true,
  "message": "OTP sent successfully",
  "session_id": "9f8b8e62-5b91-4e4b-9c7d-e91b5d6e2a11"
}
1.2 Verify OTP & Issue Tokens
Endpoint: POST /auth/otp/verify

Request:

JSON
{
  "session_id": "9f8b8e62-5b91-4e4b-9c7d-e91b5d6e2a11",
  "otp": "482910",
  "alias_name": "AyodhyaResident_04"
}
Response (200 OK):

JSON
{
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "user": {
    "id": "c3b88b72-749e-4e4a-b5e2-63a12903b412",
    "alias_name": "AyodhyaResident_04",
    "tier": "free",
    "is_verified": true
  }
}
2. Location & Geofencing
2.1 Update Resident Location Ping
Endpoint: PUT /location/sync

Request:

JSON
{
  "latitude": 26.7922,
  "longitude": 82.1998,
  "pincode": "224001",
  "preferred_radius_meters": 1500
}
Response (200 OK):

JSON
{
  "success": true,
  "active_radius_meters": 1500,
  "zone_name": "Faizabad-Ayodhya Central"
}
3. Hyperlocal Feeds & Posts
3.1 Fetch Radius Feed (With Native Ads Injected)
Endpoint: GET /posts/feed?page=1&limit=15

Response (200 OK):

JSON
{
  "page": 1,
  "total_items": 15,
  "data": [
    {
      "type": "community_post",
      "id": "e4b11f23-91ac-46d2-8bfe-98a0021c1722",
      "author_alias": "Nagarik_99",
      "category": "civic_issue",
      "title": "Water pipeline maintenance update",
      "content": "Sector 4 line repair scheduled between 2 PM to 5 PM today.",
      "distance_meters": 340,
      "upvotes": 12,
      "created_at": "2026-08-22T10:15:00Z"
    },
    {
      "type": "native_ad",
      "id": "ad_8892_bx",
      "business_name": "Gupta Diagnostic Center",
      "tagline": "Special 20% off for verified local residents",
      "cta_title": "Contact on WhatsApp",
      "whatsapp_url": "[https://wa.me/919876543210?text=NearoOffer](https://wa.me/919876543210?text=NearoOffer)",
      "distance_meters": 820
    }
  ]
}
3.2 Create Neighborhood Post
Endpoint: POST /posts

Request:

JSON
{
  "category": "help_needed",
  "title": "Urgent B+ Blood Donor Needed",
  "content": "Required at District Hospital within 2 hours.",
  "latitude": 26.7925,
  "longitude": 82.2001
}
Response (201 Created):

JSON
{
  "id": "71ac45d2-092b-42fa-a83d-e6b010c71fa1",
  "status": "published",
  "created_at": "2026-08-22T10:30:00Z"
}
4. Civic SOS & Emergency Dispatch
4.1 Trigger Instant SOS Broadcast
Endpoint: POST /sos/broadcast

Request:

JSON
{
  "emergency_type": "security",
  "description": "Suspicious cyber scammer trying forced entry claiming digital arrest verification.",
  "latitude": 26.7930,
  "longitude": 82.1990
}
Response (201 Created):

JSON
{
  "sos_id": "b182aa19-612a-4311-89ce-37bb184201ac",
  "status": "active",
  "broadcast_radius_meters": 1500,
  "dispatched_notifications_count": 84
}
5. Monetization & Subscriptions
5.1 Create Subscription Order
Endpoint: POST /subscriptions/create-order

Request:

JSON
{
  "tier": "pro_resident",
  "duration_months": 1
}
Response (200 OK):

JSON
{
  "order_id": "order_NX8271hskd9",
  "amount_inr": 29.00,
  "currency": "INR",
  "tier": "pro_resident"
}