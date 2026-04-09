import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Account(Base):
    __tablename__ = "accounts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)  # bank|cash|credit_card|crypto
    currency: Mapped[str] = mapped_column(String(10), nullable=False, default="USD")
    balance: Mapped[float] = mapped_column(Numeric(18, 8), nullable=False, default=0)
    color: Mapped[str] = mapped_column(String(7), nullable=False, default="#4A90E2")
    icon: Mapped[str] = mapped_column(String, nullable=False, default="account_balance")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    transactions: Mapped[list["Transaction"]] = relationship(  # noqa: F821
        "Transaction", back_populates="account", foreign_keys="Transaction.account_id"
    )
