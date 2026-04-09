"""
Exchange rate service using frankfurter.app (free, no API key needed).
Rates are cached in-memory for 1 hour.
"""
import logging
from datetime import datetime, timedelta, timezone

import httpx

logger = logging.getLogger(__name__)

_cache: dict[str, tuple[dict, datetime]] = {}  # base_currency -> (rates, fetched_at)
CACHE_TTL = timedelta(hours=1)
EXCHANGE_URL = "https://open.er-api.com/v6/latest"

# Approximate fallback rates relative to USD (used when API is unreachable)
_FALLBACK_USD: dict[str, float] = {
    "USD": 1.0,    "EUR": 0.92,  "GBP": 0.79,   "JPY": 149.5,
    "CAD": 1.36,   "AUD": 1.53,  "CHF": 0.90,   "CNY": 7.24,
    "INR": 83.1,   "TRY": 32.5,  "RUB": 91.5,   "KRW": 1325.0,
    "BRL": 5.0,    "SEK": 10.4,  "NOK": 10.6,   "DKK": 6.88,
    "PLN": 3.96,   "HUF": 356.0, "CZK": 22.9,   "MXN": 17.1,
    "SGD": 1.34,   "HKD": 7.82,  "NZD": 1.63,   "ZAR": 18.6,
    "UZS": 12700.0, "TJS": 10.9,
}


def _rebase_fallback(base: str) -> dict[str, float]:
    """Convert _FALLBACK_USD rates to a different base currency."""
    base_rate = _FALLBACK_USD.get(base, 1.0)
    return {k: v / base_rate for k, v in _FALLBACK_USD.items()}


async def get_rates(base: str = "USD") -> dict[str, float]:
    """Return exchange rates with `base` as 1.0. Cached for 1 hour."""
    base = base.upper()
    now = datetime.now(timezone.utc)

    if base in _cache:
        rates, fetched_at = _cache[base]
        if now - fetched_at < CACHE_TTL:
            return rates

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(f"{EXCHANGE_URL}/{base}")
            r.raise_for_status()
            data = r.json()
            rates = {k.upper(): float(v) for k, v in data["rates"].items()}
            _cache[base] = (rates, now)
            logger.info(f"Fetched live exchange rates for {base}")
            return rates
    except Exception as e:
        logger.warning(f"Exchange API unavailable ({e}), using fallback rates for {base}")
        if base in _cache:
            return _cache[base][0]
        return _rebase_fallback(base)


async def convert(amount: float, from_currency: str, to_currency: str) -> float:
    """Convert amount from one currency to another."""
    from_currency = from_currency.upper()
    to_currency = to_currency.upper()
    if from_currency == to_currency:
        return amount
    rates = await get_rates(from_currency)
    rate = rates.get(to_currency)
    if rate is None:
        # Try reverse
        rates_to = await get_rates(to_currency)
        rate_rev = rates_to.get(from_currency)
        if rate_rev:
            return amount / rate_rev
        logger.warning(f"No rate found for {from_currency}->{to_currency}, returning original")
        return amount
    return amount * rate
