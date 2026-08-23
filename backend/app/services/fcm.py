import logging
from typing import Any

from app.core.firebase import get_firebase_app

logger = logging.getLogger(__name__)


class FCMService:
    @staticmethod
    async def send_sos_multicast(
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Broadcast an emergency push notification to multiple device tokens via FCM.

        Uses firebase_admin.messaging.MulticastMessage.
        """
        valid_tokens = [t.strip() for t in tokens if t and isinstance(t, str) and t.strip()]
        if not valid_tokens:
            logger.info("FCM multicast skipped: no recipient device tokens available.")
            return {"success_count": 0, "failure_count": 0}

        app = get_firebase_app()
        if not app:
            logger.warning("FCM multicast skipped: Firebase Admin App is not initialized.")
            return {"success_count": 0, "failure_count": len(valid_tokens)}

        try:
            from firebase_admin import messaging

            # Convert all data dict values to string (FCM requirement)
            str_data: dict[str, str] = {}
            if data:
                for k, v in data.items():
                    str_data[str(k)] = str(v) if v is not None else ""

            # Standard notification payload
            notification = messaging.Notification(
                title=title,
                body=body,
            )

            # Android-specific priority configuration for heads-up SOS alerts
            android_config = messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="nearo_sos_channel",
                    priority="max",
                    default_sound=True,
                    default_vibrate_timings=True,
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            )

            # Apple APNS configuration for critical emergency banners
            apns_config = messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                        content_available=True,
                    )
                )
            )

            # Chunk tokens in batches of 500 (FCM batch limit)
            batch_size = 500
            total_success = 0
            total_failure = 0

            for i in range(0, len(valid_tokens), batch_size):
                batch_tokens = valid_tokens[i : i + batch_size]
                multicast_msg = messaging.MulticastMessage(
                    tokens=batch_tokens,
                    notification=notification,
                    data=str_data,
                    android=android_config,
                    apns=apns_config,
                )

                try:
                    # firebase-admin 6.x supports send_each_for_multicast or send_multicast
                    if hasattr(messaging, "send_each_for_multicast"):
                        response = messaging.send_each_for_multicast(multicast_msg)
                    else:
                        response = messaging.send_multicast(multicast_msg)

                    total_success += response.success_count
                    total_failure += response.failure_count
                except Exception as batch_exc:
                    logger.warning("FCM batch send error: %s", str(batch_exc))
                    total_failure += len(batch_tokens)

            logger.info(
                "FCM multicast dispatch completed: %d success, %d failure",
                total_success,
                total_failure,
            )
            return {"success_count": total_success, "failure_count": total_failure}
        except Exception as exc:
            logger.warning("FCM multicast exception: %s", str(exc))
            return {"success_count": 0, "failure_count": len(valid_tokens)}

    @classmethod
    async def send_sos_push(
        cls,
        fcm_tokens: list[str],
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Alias for send_sos_multicast for FCM Civic SOS notifications."""
        return await cls.send_sos_multicast(tokens=fcm_tokens, title=title, body=body, data=data)
