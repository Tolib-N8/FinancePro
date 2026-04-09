from datetime import date, timedelta

from fastapi import APIRouter, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import Auth, DBSession
from app.schemas.analytics import CategoryBreakdown, ForecastOut, MonthlySummary, MonthlyTrend
from app.services.analytics_service import (
    get_category_breakdown,
    get_historical_by_category,
    get_monthly_summary,
    get_monthly_trend,
)

router = APIRouter(dependencies=[Auth])


@router.get("/summary", response_model=MonthlySummary)
async def summary(month: str | None = None, db: AsyncSession = DBSession):
    if month:
        try:
            target = date.fromisoformat(f"{month}-01")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid month format, use YYYY-MM")
    else:
        today = date.today()
        target = today.replace(day=1)
    return await get_monthly_summary(db, target)


@router.get("/by-category", response_model=list[CategoryBreakdown])
async def by_category(
    date_from: date | None = None,
    date_to: date | None = None,
    db: AsyncSession = DBSession,
):
    if not date_from:
        date_from = date.today().replace(day=1)
    if not date_to:
        date_to = date.today()
    return await get_category_breakdown(db, date_from, date_to)


@router.get("/monthly-trend", response_model=list[MonthlyTrend])
async def monthly_trend(months: int = 12, db: AsyncSession = DBSession):
    return await get_monthly_trend(db, months)


@router.get("/forecast", response_model=ForecastOut)
async def get_forecast(month: str | None = None, db: AsyncSession = DBSession):
    if month:
        try:
            target = date.fromisoformat(f"{month}-01")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid month format, use YYYY-MM")
    else:
        today = date.today()
        if today.month == 12:
            target = today.replace(year=today.year + 1, month=1, day=1)
        else:
            target = today.replace(month=today.month + 1, day=1)

    from app.ai.forecaster import get_or_create_forecast
    return await get_or_create_forecast(db, target)


@router.post("/forecast/refresh", response_model=ForecastOut)
async def refresh_forecast(month: str | None = None, db: AsyncSession = DBSession):
    if month:
        try:
            target = date.fromisoformat(f"{month}-01")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid month format, use YYYY-MM")
    else:
        today = date.today()
        if today.month == 12:
            target = today.replace(year=today.year + 1, month=1, day=1)
        else:
            target = today.replace(month=today.month + 1, day=1)

    from app.ai.forecaster import generate_forecast
    return await generate_forecast(db, target)
