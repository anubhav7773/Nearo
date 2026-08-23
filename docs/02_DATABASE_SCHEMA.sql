-- =============================================================================
-- Nearo Database Schema (PostgreSQL 16 + PostGIS)
-- Domain: nearo.asiverticals.me
-- Description: Production schema for hyperlocal feeds, civic SOS, ads & users.
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Enum Types
CREATE TYPE user_role AS ENUM ('resident', 'moderator', 'business', 'admin');
CREATE TYPE subscription_tier AS ENUM ('free', 'pro_resident', 'business_pro');
CREATE TYPE post_category AS ENUM ('general', 'alert', 'civic_issue', 'help_needed', 'trade');
CREATE TYPE sos_status AS ENUM ('active', 'resolved', 'false_alarm');
CREATE TYPE ad_type AS ENUM ('in_feed_card', 'directory_top');

-- =============================================================================
-- 1. USERS & PROFILES TABLE
-- =============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    alias_name VARCHAR(50) NOT NULL,
    avatar_url TEXT,
    role user_role DEFAULT 'resident',
    tier subscription_tier DEFAULT 'free',
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone_number);

-- =============================================================================
-- 2. USER LOCATION & GEOFENCE TABLE
-- =============================================================================
CREATE TABLE user_locations (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    pincode VARCHAR(10) NOT NULL,
    last_known_location GEOMETRY(Point, 4326) NOT NULL,
    preferred_radius_meters INT DEFAULT 1500 CHECK (preferred_radius_meters BETWEEN 500 AND 5000),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Spatial GIST Index for high-speed radius lookups
CREATE INDEX idx_user_locations_geom ON user_locations USING GIST(last_known_location);

-- =============================================================================
-- 3. POSTS & LOCAL FEED TABLE
-- =============================================================================
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category post_category DEFAULT 'general',
    title VARCHAR(150),
    content TEXT NOT NULL,
    media_urls TEXT[] DEFAULT '{}',
    location GEOMETRY(Point, 4326) NOT NULL,
    is_pinned BOOLEAN DEFAULT FALSE,
    upvotes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_posts_geom ON posts USING GIST(location);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_category ON posts(category);

-- =============================================================================
-- 4. CIVIC SOS & EMERGENCY DISPATCH TABLE
-- =============================================================================
CREATE TABLE sos_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    triggered_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emergency_type VARCHAR(50) NOT NULL, -- 'medical', 'security', 'fire', 'scam'
    description TEXT,
    initial_location GEOMETRY(Point, 4326) NOT NULL,
    current_location GEOMETRY(Point, 4326) NOT NULL,
    status sos_status DEFAULT 'active',
    responders_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_sos_events_geom ON sos_events USING GIST(current_location);
CREATE INDEX idx_sos_events_status ON sos_events(status);

-- =============================================================================
-- 5. HYPERLOCAL NATIVE ADS & SPONSORSHIPS TABLE
-- =============================================================================
CREATE TABLE local_ads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ad_type ad_type DEFAULT 'in_feed_card',
    business_name VARCHAR(100) NOT NULL,
    tagline VARCHAR(150),
    cta_title VARCHAR(50) DEFAULT 'Contact on WhatsApp',
    whatsapp_number VARCHAR(15),
    target_center GEOMETRY(Point, 4326) NOT NULL,
    target_radius_meters INT DEFAULT 3000,
    is_active BOOLEAN DEFAULT TRUE,
    impressions_count BIGINT DEFAULT 0,
    clicks_count BIGINT DEFAULT 0,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_local_ads_geom ON local_ads USING GIST(target_center);
CREATE INDEX idx_local_ads_active ON local_ads(is_active, expires_at);

-- =============================================================================
-- 6. SUBSCRIPTIONS TABLE
-- =============================================================================
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tier subscription_tier NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    gateway_order_id VARCHAR(100),
    gateway_payment_id VARCHAR(100),
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id, is_active);