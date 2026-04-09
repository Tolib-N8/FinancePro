import uuid
from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel


class ReceiptOut(BaseModel):
    id: uuid.UUID
    transaction_id: Optional[uuid.UUID] = None
    file_name: str
    mime_type: str
    merchant: Optional[str] = None
    receipt_date: Optional[date] = None
    total_amount: Optional[float] = None
    currency: Optional[str] = None
    line_items: Optional[list[Any]] = None
    ocr_status: str
    created_at: datetime

    model_config = {"from_attributes": True}
