import json
import uuid
from typing import Any, Dict, List, Optional, Tuple
from redis.asyncio import Redis
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.sos import SOSEvent, SOSStatus
from app.models.user import UserLocation
from app.schemas.sos import SOSBroadcastResponse, SOSEventDetail


class AlertService:
    @staticmethod
    async def create_and_dispatch_sos(
        db: AsyncSession,
        redis: Optional[Redis],
        user_id: uuid.UUID,
        emergency_type: str,
        description: Optional[str],
        latitude: float,
        longitude: float,
        broadcast_radius_meters: int = 1500,
    ) -> SOSBroadcastResponse:
        """Create an SOS event, query affected residents in 1,500m radius, and broadcast via Redis."""
        point_geom = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)

        # 1. Create SOSEvent record
        sos_event = SOSEvent(
            triggered_by=user_id,
            emergency_type=emergency_type,
            description=description,
            initial_location=point_geom,
            current_location=point_geom,
            status=SOSStatus.ACTIVE,
            responders_count=0,
        )
        db.add(sos_event)
        await db.commit()
        await db.refresh(sos_event)

        # 2. Query all resident user locations within 1,500m radius
        residents_stmt = (
            select(UserLocation.user_id, UserLocation.pincode)
            .where(
                func.ST_DWithin(
                    func.cast(UserLocation.last_known_location, text("geography")),
                    func.cast(point_geom, text("geography")),
                    broadcast_radius_meters,
                ),
                UserLocation.user_id != user_id,
            )
        )
        result = await db.execute(residents_stmt)
        resident_rows = result.all()
        dispatched_count = len(resident_rows)

        # Collect distinct pincodes in the area
        pincodes = list({row.pincode for row in resident_rows if row.pincode})

        # 3. Publish to Redis PubSub for real-time WebSocket dispatch
        if redis:
            payload = json.dumps({
                "event": "CIVIC_SOS_ALERT",
                "sos_id": str(sos_event.id),
                "emergency_type": emergency_type,
                "description": description,
                "latitude": latitude,
                "longitude": longitude,
                "broadcast_radius_meters": broadcast_radius_meters,
                "triggered_at": sos_event.created_at.isoformat() if sos_event.created_at else None,
            })
            try:
                # Publish to global broadcast channel
                await redis.publish("sos_channel_broadcast", payload)
                # Also publish to specific pincode channels
                for pincode in pincodes:
                    await redis.publish(f"sos_channel_{pincode}", payload)
            except Exception:
                pass  # Do not block SOS creation if pubsub fails

        return SOSBroadcastResponse(
            sos_id=sos_event.id,
            status="active",
            broadcast_radius_meters=broadcast_radius_meters,
            dispatched_notifications_count=dispatched_count,
        )

    @staticmethod
    async def fetch_active_sos(
        db: AsyncSession,
        latitude: float,
        longitude: float,
        radius_meters: int = 3000,
    ) -> List[SOSEventDetail]:
        """Fetch all active SOS emergencies within the specified geographic radius."""
        point_geom = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)

        distance_expr = func.ST_Distance(
            func.cast(SOSEvent.current_location, text("geography")),
            func.cast(point_geom, text("geography")),
        ).label("distance_meters")

        raw_lat = func.ST_Y(SOSEvent.current_location).label("raw_lat")
        raw_lon = func.ST_X(SOSEvent.current_location).label("raw_lon")

        stmt = (
            select(SOSEvent, distance_expr, raw_lat, raw_lon)
            .where(
                SOSEvent.status == SOSStatus.ACTIVE,
                func.ST_DWithin(
                    func.cast(SOSEvent.current_location, text("geography")),
                    func.cast(point_geom, text("geography")),
                    radius_meters,
                ),
            )
            .order_by(SOSEvent.created_at.desc())
        )

        result = await db.execute(stmt)
        rows = result.all()

        events: List[SOSEventDetail] = []
        for sos, dist, lat, lon in rows:
            events.append(
                SOSEventDetail(
                    id=sos.id,
                    triggered_by=sos.triggered_by,
                    emergency_type=sos.emergency_type,
                    description=sos.description,
                    status=sos.status,
                    responders_count=sos.responders_count,
                    latitude=float(lat),
                    longitude=float(lon),
                    distance_meters=int(dist) if dist is not None else None,
                    created_at=sos.created_at,
                    resolved_at=sos.resolved_at,
                )
            )

        return events
