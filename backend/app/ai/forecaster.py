import json
import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from tenacity import retry, stop_after_attempt, wait_exponential

from app.ai.client import generate
from app.models.forecast import Forecast
from app.services.analytics_service import get_historical_by_category

logger = logging.getLogger(__name__)


def _parse_json(text: str) -> dict:
    text = text.strip()
    if "```" in text:
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def _call(history: dict, target_month: str) -> dict:
    prompt = f"""You are a financial forecasting assistant.
Given historical monthly spending data, predict next month's expenses per category.
Return ONLY a JSON object:
{{
  "predictions": {{"<category_name>": <predicted_amount>}},
  "total_predicted": <number>,
  "confidence": "low|medium|high",
  "reasoning": "<1-2 sentences>"
}}

Historical data (last 6 months):
{json.dumps(history, indent=2)}

Target month: {target_month}"""
    text = await generate(prompt, max_tokens=512, temperature=0.3)
    return _parse_json(text)


async def generate_forecast(db: AsyncSession, target_month: date) -> Forecast:
    history = await get_historical_by_category(db, months=6)
    target_str = target_month.strftime("%Y-%m")
    result = await _call(history, target_str)

    existing = await db.execute(select(Forecast).where(Forecast.month == target_month))
    forecast = existing.scalar_one_or_none()

    if forecast:
        forecast.predictions = result.get("predictions", {})
        forecast.total_predicted = result.get("total_predicted")
        forecast.confidence = result.get("confidence")
        forecast.generated_at = datetime.now(timezone.utc)
    else:
        forecast = Forecast(
            month=target_month,
            predictions=result.get("predictions", {}),
            total_predicted=result.get("total_predicted"),
            confidence=result.get("confidence"),
        )
        db.add(forecast)

    await db.flush()
    await db.refresh(forecast)
    return forecast


async def get_or_create_forecast(db: AsyncSession, target_month: date) -> Forecast:
    existing = await db.execute(select(Forecast).where(Forecast.month == target_month))
    forecast = existing.scalar_one_or_none()
    if forecast:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        if forecast.generated_at.replace(tzinfo=timezone.utc) > cutoff:
            return forecast
    return await generate_forecast(db, target_month)
