import uuid
from datetime import date

from pydantic import BaseModel, Field


class StatementImportSample(BaseModel):
    date: date
    type: str = Field(pattern="^(income|expense)$")
    amount: float
    currency: str
    description: str


class StatementImportResult(BaseModel):
    account_id: uuid.UUID
    parsed_count: int
    imported_count: int
    skipped_duplicates: int
    sample: list[StatementImportSample] = []
