import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.category import CategoryOut
from app.schemas.comment import CommentOut
from app.schemas.receipt import ReceiptOut


class TransactionBase(BaseModel):
    account_id: uuid.UUID
    to_account_id: Optional[uuid.UUID] = None
    type: str = Field(pattern="^(income|expense|transfer)$")
    amount: float
    currency: str
    date: date
    description: Optional[str] = None
    category_id: Optional[uuid.UUID] = None
    is_recurring: bool = False


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    account_id: Optional[uuid.UUID] = None
    to_account_id: Optional[uuid.UUID] = None
    type: Optional[str] = None
    amount: Optional[float] = None
    currency: Optional[str] = None
    date: Optional[date] = None
    description: Optional[str] = None
    category_id: Optional[uuid.UUID] = None
    is_recurring: Optional[bool] = None


class TransactionOut(TransactionBase):
    id: uuid.UUID
    amount_base: Optional[float] = None
    ai_categorized: bool
    created_at: datetime
    updated_at: datetime
    category: Optional[CategoryOut] = None

    model_config = {"from_attributes": True}


class TransactionDetail(TransactionOut):
    comments: list[CommentOut] = []
    receipts: list[ReceiptOut] = []

    model_config = {"from_attributes": True}


class PaginatedTransactions(BaseModel):
    items: list[TransactionOut]
    total: int
    page: int
    page_size: int
