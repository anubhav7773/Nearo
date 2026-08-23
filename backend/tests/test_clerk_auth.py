from app.core.auth import extract_clerk_user_claims
from app.core.config import settings


def test_extract_clerk_user_claims():
    payload = {
        "sub": "user_2test12345678",
        "phone_number": "+919876543210",
        "email": "user@example.com",
        "first_name": "AyodhyaResident",
    }
    claims = extract_clerk_user_claims(payload)
    assert claims["sub"] == "user_2test12345678"
    assert claims["phone_number"] == "+919876543210"
    assert claims["email"] == "user@example.com"
    assert claims["alias_name"] == "AyodhyaResident"


def test_extract_clerk_user_claims_fallback_phone():
    payload = {
        "sub": "user_9876543210",
    }
    claims = extract_clerk_user_claims(payload)
    assert claims["sub"] == "user_9876543210"
    assert claims["phone_number"].startswith("+91")
    assert claims["alias_name"] == "Resident_3210"


def test_cors_origin_parser():
    origins = settings.assemble_cors_origins(
        "http://localhost:3000, https://nearo.asiverticals.me"
    )
    assert "http://localhost:3000" in origins
    assert "https://nearo.asiverticals.me" in origins
