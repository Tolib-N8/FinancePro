import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class CommentCreate(BaseModel):
    body: str


class CommentUpdate(BaseModel):
    body: Optional[str] = None


class CommentOut(BaseModel):
    id: uuid.UUID
    transaction_id: uuid.UUID
    body: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
