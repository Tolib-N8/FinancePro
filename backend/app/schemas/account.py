import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AccountBase(BaseModel):
    name: str
    type: str = Field(pattern="^(bank|cash|credit_card|crypto)$")
    currency: str = "USD"
    color: str = "#4A90E2"
    icon: str = "account_balance"


class AccountCreate(AccountBase):
    balance: float = 0.0


class AccountUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    currency: Optional[str] = None
    balance: Optional[float] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    is_active: Optional[bool] = None


class AccountOut(AccountBase):
    id: uuid.UUID
    balance: float
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
