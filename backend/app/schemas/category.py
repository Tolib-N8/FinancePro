import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class CategoryBase(BaseModel):
    name: str
    color: str = "#888888"
    icon: str = "label"
    parent_id: Optional[uuid.UUID] = None


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None
    icon: Optional[str] = None
    parent_id: Optional[uuid.UUID] = None


class CategoryOut(CategoryBase):
    id: uuid.UUID
    is_system: bool
    created_at: datetime

    model_config = {"from_attributes": True}
