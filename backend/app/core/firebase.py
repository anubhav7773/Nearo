import json
import logging
import os
from typing import Any

import jwt
from app.core.config import settings

logger = logging.getLogger(__name__)

_firebase_initialized = False


def get_firebase_app():
    """Initialize or retrieve the Firebase Admin App instance."""
    global _firebase_initialized
    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            return firebase_admin.get_app()

        cred = None
        service_account_raw = (
            settings.FIREBASE_SERVICE_ACCOUNT
            or settings.FIREBASE_SERVICE_ACCOUNT_JSON
            or settings.FIREBASE_CREDENTIALS_JSON
            or os.getenv("FIREBASE_SERVICE_ACCOUNT")
            or os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
        )

        if service_account_raw:
            try:
                cert_dict = json.loads(service_account_raw)
                cred = credentials.Certificate(cert_dict)
            except Exception as e:
                logger.warning("Failed to parse FIREBASE_SERVICE_ACCOUNT JSON: %s", str(e))

        elif settings.FIREBASE_SERVICE_ACCOUNT_PATH and os.path.exists(
            settings.FIREBASE_SERVICE_ACCOUNT_PATH
        ):
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)

        if cred:
            app = firebase_admin.initialize_app(cred)
        else:
            # Initialize with default credentials or project id
            app = firebase_admin.initialize_app(
                options={"projectId": settings.FIREBASE_PROJECT_ID or "nearo-org"}
            )

        _firebase_initialized = True
        logger.info("Firebase Admin initialized successfully.")
        return app
    except Exception as exc:
        logger.warning(
            "Firebase Admin SDK initialization skipped/deferred: %s", str(exc)
        )
        return None


def verify_firebase_token(token: str) -> dict[str, Any]:
    """Decodes and verifies a Firebase ID Token using Firebase Admin SDK.

    Returns payload dict containing uid, email, phone_number, name, picture.
    """
    if not token:
        raise ValueError("Empty token")

    # Fast header check: Firebase ID tokens use RS256 with a Key ID (kid)
    try:
        unverified_headers = jwt.get_unverified_header(token)
        alg = unverified_headers.get("alg")
        if alg != "RS256" or "kid" not in unverified_headers:
            raise ValueError("Token does not match Firebase RS256 token format")
    except Exception as e:
        raise ValueError(f"Token is not a Firebase token: {e}") from e

    try:
        from firebase_admin import auth

        get_firebase_app()
        decoded_token = auth.verify_id_token(token, check_revoked=False)
        return {
            "uid": decoded_token.get("uid"),
            "email": decoded_token.get("email"),
            "phone_number": decoded_token.get("phone_number"),
            "name": decoded_token.get("name"),
            "avatar_url": decoded_token.get("picture"),
            "firebase": decoded_token,
        }
    except Exception as exc:
        logger.debug("Firebase verification exception: %s", str(exc))
        raise ValueError(f"Invalid Firebase ID token: {exc}") from exc
