import uuid
from datetime import datetime, timezone

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_password_hash,
    verify_password,
)
from app.models.user import SubscriptionTier
from app.schemas.ad import NativeAdResponse
from app.schemas.post import PostResponse
from app.schemas.user import OTPSendRequest, OTPVerifyRequest
from app.services.ad_engine import AdEngine
from app.services.geo_service import apply_coordinate_jitter


def test_password_hashing():
    pwd = "Secr3tPassword!@#"
    hashed = get_password_hash(pwd)
    assert hashed != pwd
    assert verify_password(pwd, hashed) is True
    assert verify_password("WrongPassword", hashed) is False


def test_jwt_tokens():
    user_id = str(uuid.uuid4())
    access_token = create_access_token(subject=user_id)
    payload = decode_token(access_token)
    assert payload["sub"] == user_id
    assert payload["type"] == "access"
    assert "jti" in payload

    refresh_token = create_refresh_token(subject=user_id)
    r_payload = decode_token(refresh_token)
    assert r_payload["sub"] == user_id
    assert r_payload["type"] == "refresh"


def test_coordinate_jitter():
    lat, lon = 26.7922, 82.1998
    j_lat, j_lon = apply_coordinate_jitter(lat, lon, min_meters=75.0, max_meters=125.0)

    # Must be shifted but within ~0.002 degrees (< 200m)
    assert j_lat != lat
    assert j_lon != lon
    assert abs(j_lat - lat) < 0.003
    assert abs(j_lon - lon) < 0.003


def test_ad_engine_injection_and_pro_exclusion():
    # Create 10 dummy posts
    posts = [
        PostResponse(
            id=uuid.uuid4(),
            author_alias=f"Resident_{i}",
            category="general",
            content=f"Post content {i}",
            distance_meters=i * 100,
            upvotes=i,
            created_at=datetime.now(timezone.utc),
        )
        for i in range(10)
    ]

    # Create 2 dummy ads
    ads = [
        NativeAdResponse(
            id=f"ad_{i}",
            business_name=f"Business {i}",
            cta_title="Contact",
            distance_meters=500,
        )
        for i in range(2)
    ]

    # Free resident feed should have ad injected after 6th post
    free_feed = AdEngine.inject_native_ads(posts, ads, user_tier=SubscriptionTier.FREE)
    assert len(free_feed) == 11
    assert getattr(free_feed[6], "type", None) == "native_ad"

    # Pro resident should receive 0 injected ads
    pro_feed = AdEngine.inject_native_ads(
        posts, ads, user_tier=SubscriptionTier.PRO_RESIDENT
    )
    assert len(pro_feed) == 10
    assert all(getattr(item, "type", None) == "community_post" for item in pro_feed)


def test_otp_schemas():
    req = OTPSendRequest(phone_number="+919876543210")
    assert req.phone_number == "+919876543210"

    v_req = OTPVerifyRequest(session_id="dummy-session", otp="482910")
    assert v_req.otp == "482910"
