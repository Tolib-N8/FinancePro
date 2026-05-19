import pytest

from app.services import exchange_service


async def test_convert_same_currency_is_identity():
    assert await exchange_service.convert(100.0, "USD", "USD") == 100.0
    assert await exchange_service.convert(50.0, "usd", "USD") == 50.0


async def test_convert_direct_rate(monkeypatch):
    async def fake_get_rates(base):
        assert base == "USD"
        return {"EUR": 0.92, "GBP": 0.79}

    monkeypatch.setattr(exchange_service, "get_rates", fake_get_rates)
    assert await exchange_service.convert(100.0, "USD", "EUR") == pytest.approx(92.0)


async def test_convert_reverse_rate(monkeypatch):
    async def fake_get_rates(base):
        if base == "EUR":
            return {"GBP": 0.85}  # no USD key -> forces reverse lookup
        if base == "USD":
            return {"EUR": 0.92}
        return {}

    monkeypatch.setattr(exchange_service, "get_rates", fake_get_rates)
    # EUR->USD: rates(EUR) lacks USD, so amount / rates(USD)[EUR]
    assert await exchange_service.convert(92.0, "EUR", "USD") == pytest.approx(100.0)


async def test_convert_no_rate_returns_original(monkeypatch):
    async def fake_get_rates(base):
        return {}

    monkeypatch.setattr(exchange_service, "get_rates", fake_get_rates)
    assert await exchange_service.convert(123.0, "USD", "XXX") == 123.0


def test_rebase_fallback_is_pure():
    rebased = exchange_service._rebase_fallback("EUR")
    assert rebased["EUR"] == pytest.approx(1.0)
    assert rebased["USD"] == pytest.approx(1 / 0.92)
