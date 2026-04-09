from datetime import date
from typing import Any, Optional

from pydantic import BaseModel


class MonthlySummary(BaseModel):
    month: str
    income: float
    expenses: float
    savings: float
    net: float


class CategoryBreakdown(BaseModel):
    category_id: Optional[str] = None
    category_name: str
    total: float
    percentage: float
    color: str


class MonthlyTrend(BaseModel):
    month: str
    income: float
    expenses: float


class ForecastOut(BaseModel):
    month: date
    predictions: dict[str, Any]
    total_predicted: Optional[float] = None
    confidence: Optional[str] = None
    generated_at: Optional[Any] = None
