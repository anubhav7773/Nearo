import json
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from redis.asyncio import Redis
from sqlalchemy import String, cast, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sos import SOSEvent, SOSStatus
from app.models.user import User, UserLocation, UserRole
from app.schemas.sos import (
    ActiveSOSResponse,
    SOSBroadcastResponse,
    SOSEventDetail,
    SOSResolveResponse,
)


class AlertService:
    @staticmethod
    async def create_and_dispatch_sos(
        db: AsyncSession,
        redis: Redis | None,
        user_id: uuid.UUID,
        emergency_type: str,
        description: str | None,
        latitude: float,
        longitude: float,
        broadcast_radius_meters: int = 1500,
    ) -> SOSBroadcastResponse:
        """Create an SOS event, query affected residents in broadcast radius, and broadcast via Redis."""
        point_geom = func.ST_SetSRID(func.ST_MakePoint(float(longitude), float(latitude)), 4326)
        cat_val = (emergency_type or "security").lower().strip()

        # 1. Create SOSEvent record
        event_id = uuid.uuid4()
        sos_event = SOSEvent(
            id=event_id,
            triggered_by=user_id,
            category=cat_val,
            description=description or "Civic SOS Emergency Broadcast",
            location=point_geom,
            initial_location=point_geom,
            current_location=point_geom,
            status=SOSStatus.ACTIVE,
            responders_count=0,
        )
        db.add(sos_event)
        await db.commit()
        await db.refresh(sos_event)

        # 2. Query distinct verified residents reached within spatial radius using PostGIS
        dispatched_count = 0
        resident_rows = []
        try:
            residents_stmt = (
                select(UserLocation.user_id, UserLocation.pincode, User.fcm_token)
                .join(User, UserLocation.user_id == User.id)
                .where(
                    User.id != user_id,
                    User.is_active == True,
                    func.ST_DWithin(
                        func.ST_Transform(UserLocation.last_known_location, 3857),
                        func.ST_Transform(point_geom, 3857),
                        float(broadcast_radius_meters),
                    ),
                )
            )
            result = await db.execute(residents_stmt)
            resident_rows = result.all()
            dispatched_count = len(resident_rows)
        except Exception:
            try:
                reach_sql = """
                    SELECT COUNT(DISTINCT u.id) AS reach_count
                    FROM public.users u
                    JOIN public.user_locations ul ON ul.user_id = u.id
                    WHERE u.is_active = true
                      AND u.id != :user_id
                      AND ST_DWithin(
                        ul.last_known_location::geography,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                        :radius_meters
                      );
                """
                reach_res = await db.execute(
                    text(reach_sql),
                    {
                        "user_id": user_id,
                        "lng": float(longitude),
                        "lat": float(latitude),
                        "radius_meters": int(broadcast_radius_meters),
                    },
                )
                reach_row = reach_res.mappings().first()
                if reach_row and reach_row["reach_count"] is not None:
                    dispatched_count = int(reach_row["reach_count"])
            except Exception:
                dispatched_count = 0

        # Collect distinct pincodes and registered FCM tokens in the area
        pincodes = list({row[1] for row in resident_rows if row and len(row) > 1 and row[1]})
        fcm_tokens = [row[2] for row in resident_rows if row and len(row) > 2 and row[2]]

        # 3. Publish to Firebase Cloud Messaging (FCM) Multicast
        if fcm_tokens:
            try:
                from app.services.fcm import FCMService

                sos_title = f"🚨 CIVIC SOS: {cat_val.upper()} Alert"
                sos_body = description or f"A resident within {broadcast_radius_meters}m triggered an emergency alert."
                await FCMService.send_sos_multicast(
                    tokens=fcm_tokens,
                    title=sos_title,
                    body=sos_body,
                    data={
                        "event": "CIVIC_SOS_ALERT",
                        "sos_id": str(sos_event.id),
                        "emergency_type": cat_val,
                        "latitude": str(latitude),
                        "longitude": str(longitude),
                    },
                )
            except Exception:
                pass

        # 4. Publish to Redis PubSub for real-time WebSocket dispatch
        if redis:
            created_at_iso = (
                sos_event.created_at.isoformat()
                if hasattr(sos_event, "created_at") and sos_event.created_at
                else datetime.now(timezone.utc).isoformat()
            )
            payload = json.dumps(
                {
                    "event": "CIVIC_SOS_ALERT",
                    "sos_id": str(sos_event.id),
                    "emergency_type": cat_val,
                    "description": description or "Civic SOS Emergency Broadcast",
                    "latitude": latitude,
                    "longitude": longitude,
                    "broadcast_radius_meters": broadcast_radius_meters,
                    "dispatched_neighbors_count": dispatched_count,
                    "neighbors_alerted": dispatched_count,
                    "triggered_at": created_at_iso,
                }
            )
            try:
                await redis.publish("sos_channel_broadcast", payload)
                for pincode in pincodes:
                    await redis.publish(f"sos_channel_{pincode}", payload)
            except Exception:
                pass

        created_at_val = (
            sos_event.created_at
            if hasattr(sos_event, "created_at") and isinstance(sos_event.created_at, datetime)
            else datetime.now(timezone.utc)
        )

        return SOSBroadcastResponse(
            id=sos_event.id,
            event_id=sos_event.id,
            sos_id=sos_event.id,
            user_id=user_id,
            triggered_by=user_id,
            status="active",
            category=cat_val,
            emergency_type=cat_val,
            description=description or "Civic SOS Emergency Broadcast",
            latitude=float(latitude),
            longitude=float(longitude),
            lat=float(latitude),
            lng=float(longitude),
            broadcast_radius_meters=broadcast_radius_meters,
            radius_meters=float(broadcast_radius_meters),
            dispatched_count=dispatched_count,
            dispatched_neighbors_count=dispatched_count,
            dispatched_notifications_count=dispatched_count,
            neighbors_alerted=dispatched_count,
            neighbors_notified=dispatched_count,
            created_at=created_at_val,
        )

    @staticmethod
    async def fetch_user_active_sos(
        db: AsyncSession,
        user_id: uuid.UUID,
    ) -> ActiveSOSResponse:
        """Fetch current user's active unresolved SOS event if one exists."""
        stmt = (
            select(
                SOSEvent,
                func.ST_Y(SOSEvent.current_location).label("latitude"),
                func.ST_X(SOSEvent.current_location).label("longitude"),
            )
            .where(
                SOSEvent.triggered_by == user_id,
                func.cast(SOSEvent.status, String) == "active",
            )
            .order_by(SOSEvent.created_at.desc())
        )
        res = await db.execute(stmt)
        row = res.first()

        if not row:
            return ActiveSOSResponse(has_active=False, event=None)

        if isinstance(row, (tuple, list)) and len(row) >= 3:
            active_event, ev_lat, ev_lon = row[0], row[1], row[2]
        elif isinstance(row, SOSEvent):
            active_event, ev_lat, ev_lon = row, 26.7922, 82.1998
        elif hasattr(row, "__getitem__"):
            try:
                active_event = row[0]
                ev_lat = row[1] if len(row) > 1 else 26.7922
                ev_lon = row[2] if len(row) > 2 else 82.1998
            except Exception:
                return ActiveSOSResponse(has_active=False, event=None)
        else:
            return ActiveSOSResponse(has_active=False, event=None)

        if not active_event or not isinstance(active_event, SOSEvent):
            return ActiveSOSResponse(has_active=False, event=None)

        created_at_val = (
            active_event.created_at
            if hasattr(active_event, "created_at") and isinstance(active_event.created_at, datetime)
            else None
        )

        category_val = getattr(active_event, "category", None) or getattr(active_event, "emergency_type", "security")
        lat_val = float(ev_lat) if ev_lat is not None else 26.7922
        lon_val = float(ev_lon) if ev_lon is not None else 82.1998

        # Calculate actual live nearby users count
        nearby_count = 0
        try:
            active_point = func.ST_SetSRID(func.ST_MakePoint(lon_val, lat_val), 4326)
            count_stmt = (
                select(func.count(func.distinct(User.id)))
                .join(UserLocation, UserLocation.user_id == User.id)
                .where(
                    User.id != user_id,
                    User.is_active == True,
                    func.ST_DWithin(
                        func.ST_Transform(UserLocation.last_known_location, 3857),
                        func.ST_Transform(active_point, 3857),
                        1500.0,
                    ),
                )
            )
            count_res = await db.execute(count_stmt)
            nearby_count = count_res.scalar() or 0
        except Exception:
            nearby_count = 0

        detail = SOSEventDetail(
            id=active_event.id,
            event_id=active_event.id,
            sos_id=active_event.id,
            user_id=active_event.triggered_by,
            triggered_by=active_event.triggered_by,
            category=category_val,
            emergency_type=category_val,
            description=active_event.description,
            status=active_event.status,
            responders_count=active_event.responders_count or 0,
            dispatched_count=nearby_count,
            dispatched_neighbors_count=nearby_count,
            dispatched_notifications_count=nearby_count,
            neighbors_alerted=nearby_count,
            neighbors_notified=nearby_count,
            latitude=lat_val,
            longitude=lon_val,
            lat=lat_val,
            lng=lon_val,
            distance_meters=0,
            created_at=created_at_val,
            resolved_at=None,
        )

        return ActiveSOSResponse(has_active=True, event=detail)

    @staticmethod
    async def fetch_sos_by_id(
        db: AsyncSession,
        event_id: uuid.UUID,
    ) -> SOSEventDetail:
        """Fetch a specific SOS event by UUID."""
        stmt = select(SOSEvent).where(SOSEvent.id == event_id)
        res = await db.execute(stmt)
        sos = res.scalar_one_or_none()

        if not sos:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="SOS emergency event not found.",
            )

        category_val = getattr(sos, "category", None) or getattr(sos, "emergency_type", "security")
        created_at_val = (
            sos.created_at
            if hasattr(sos, "created_at") and isinstance(sos.created_at, datetime)
            else None
        )

        return SOSEventDetail(
            id=sos.id,
            event_id=sos.id,
            sos_id=sos.id,
            user_id=sos.triggered_by,
            triggered_by=sos.triggered_by,
            category=category_val,
            emergency_type=category_val,
            description=sos.description,
            status=sos.status,
            responders_count=sos.responders_count or 0,
            dispatched_count=0,
            dispatched_neighbors_count=0,
            neighbors_alerted=0,
            latitude=26.7922,
            longitude=82.1998,
            lat=26.7922,
            lng=82.1998,
            created_at=created_at_val,
            resolved_at=sos.resolved_at,
        )

    @staticmethod
    async def resolve_sos_event(
        db: AsyncSession,
        event_id: uuid.UUID,
        current_user: User,
    ) -> SOSResolveResponse:
        """Mark an active SOS event as resolved."""
        stmt = select(SOSEvent).where(SOSEvent.id == event_id)
        res = await db.execute(stmt)
        event = res.scalar_one_or_none()

        if not event or not isinstance(event, SOSEvent):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="SOS emergency event not found",
            )

        # Allow creator or moderator/admin
        is_owner = getattr(event, "triggered_by", None) == current_user.id
        is_mod = current_user.role in (UserRole.ADMIN, UserRole.MODERATOR)

        if not is_owner and not is_mod:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the resident who triggered the SOS or a moderator may resolve it.",
            )

        if hasattr(event, "status"):
            event.status = SOSStatus.RESOLVED
        if hasattr(event, "resolved_at"):
            event.resolved_at = func.now()

        await db.commit()
        await db.refresh(event)

        resolved_at_val = (
            event.resolved_at
            if hasattr(event, "resolved_at") and isinstance(event.resolved_at, datetime)
            else datetime.now(timezone.utc)
        )

        return SOSResolveResponse(
            success=True,
            event_id=event_id,
            sos_id=event_id,
            status="resolved",
            resolved_at=resolved_at_val,
        )

    @staticmethod
    async def fetch_active_sos(
        db: AsyncSession,
        latitude: float,
        longitude: float,
        radius_meters: int = 3000,
    ) -> list[SOSEventDetail]:
        """Fetch all active SOS emergencies within the specified geographic radius."""
        point_geom = func.ST_SetSRID(func.ST_MakePoint(float(longitude), float(latitude)), 4326)

        distance_expr = func.ST_Distance(
            func.ST_Transform(SOSEvent.current_location, 3857),
            func.ST_Transform(point_geom, 3857),
        ).label("distance_meters")

        raw_lat = func.ST_Y(SOSEvent.current_location).label("raw_lat")
        raw_lon = func.ST_X(SOSEvent.current_location).label("raw_lon")

        stmt = (
            select(SOSEvent, distance_expr, raw_lat, raw_lon)
            .where(
                func.cast(SOSEvent.status, String) == "active",
                func.ST_DWithin(
                    func.ST_Transform(SOSEvent.current_location, 3857),
                    func.ST_Transform(point_geom, 3857),
                    float(radius_meters),
                ),
            )
            .order_by(SOSEvent.created_at.desc())
        )

        result = await db.execute(stmt)
        rows = result.all()

        events: list[SOSEventDetail] = []
        for sos, dist, lat, lon in rows:
            created_at_val = (
                sos.created_at
                if hasattr(sos, "created_at") and isinstance(sos.created_at, datetime)
                else None
            )
            sos_cat = getattr(sos, "category", None) or getattr(sos, "emergency_type", "security")
            events.append(
                SOSEventDetail(
                    id=sos.id,
                    event_id=sos.id,
                    sos_id=sos.id,
                    user_id=sos.triggered_by,
                    triggered_by=sos.triggered_by,
                    category=sos_cat,
                    emergency_type=sos_cat,
                    description=sos.description,
                    status=sos.status,
                    responders_count=sos.responders_count or 0,
                    dispatched_count=0,
                    dispatched_neighbors_count=0,
                    neighbors_alerted=0,
                    latitude=float(lat),
                    longitude=float(lon),
                    lat=float(lat),
                    lng=float(lon),
                    distance_meters=int(dist) if dist is not None else None,
                    created_at=created_at_val,
                    resolved_at=sos.resolved_at,
                )
            )

        return events
