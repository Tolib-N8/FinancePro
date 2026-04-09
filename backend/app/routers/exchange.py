from fastapi import APIRouter, HTTPException

from app.config import settings
from app.dependencies import Auth
from app.services.exchange_service import convert, get_rates

router = APIRouter(dependencies=[Auth])


@router.get("/rates")
async def exchange_rates(base: str | None = None):
    """Get exchange rates. Defaults to BASE_CURRENCY from settings."""
    base_currency = (base or settings.base_currency).upper()
    rates = await get_rates(base_currency)
    return {"base": base_currency, "rates": rates}


@router.get("/convert")
async def convert_currency(amount: float, from_currency: str, to_currency: str):
    """Convert an amount between currencies."""
    try:
        result = await convert(amount, from_currency.upper(), to_currency.upper())
        return {
            "amount": amount,
            "from": from_currency.upper(),
            "to": to_currency.upper(),
            "result": round(result, 8),
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
