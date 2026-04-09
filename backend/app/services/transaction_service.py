import uuid
from datetime import date

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models.account import Account
from app.models.transaction import Transaction
from app.schemas.transaction import TransactionCreate, TransactionUpdate
from app.services.exchange_service import convert


async def _converted_amount(tx_amount: float, tx_currency: str, acc_currency: str) -> float:
    """Return tx_amount converted to account's currency."""
    if tx_currency.upper() == acc_currency.upper():
        return tx_amount
    return await convert(tx_amount, tx_currency, acc_currency)


async def _apply_balance(db: AsyncSession, tx: Transaction, multiplier: float) -> None:
    """Apply transaction effect to account balance(s), converting to each account's currency."""
    acc = await db.get(Account, tx.account_id)
    if acc is None:
        return

    amount_in_acc = await _converted_amount(float(tx.amount), tx.currency, acc.currency)

    if tx.type == "income":
        acc.balance = float(acc.balance) + multiplier * amount_in_acc
    elif tx.type == "expense":
        acc.balance = float(acc.balance) - multiplier * amount_in_acc
    elif tx.type == "transfer":
        acc.balance = float(acc.balance) - multiplier * amount_in_acc
        if tx.to_account_id:
            to_acc = await db.get(Account, tx.to_account_id)
            if to_acc:
                # Convert to destination account's currency
                amount_in_to = await _converted_amount(float(tx.amount), tx.currency, to_acc.currency)
                to_acc.balance = float(to_acc.balance) + multiplier * amount_in_to


async def list_transactions(
    db: AsyncSession,
    account_id: uuid.UUID | None = None,
    category_id: uuid.UUID | None = None,
    tx_type: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    search: str | None = None,
    page: int = 1,
    page_size: int = 50,
) -> tuple[list[Transaction], int]:
    query = select(Transaction).options(selectinload(Transaction.category))

    if account_id:
        query = query.where(
            or_(Transaction.account_id == account_id, Transaction.to_account_id == account_id)
        )
    if category_id:
        query = query.where(Transaction.category_id == category_id)
    if tx_type:
        query = query.where(Transaction.type == tx_type)
    if date_from:
        query = query.where(Transaction.date >= date_from)
    if date_to:
        query = query.where(Transaction.date <= date_to)
    if search:
        query = query.where(Transaction.description.ilike(f"%{search}%"))

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar()

    query = query.order_by(Transaction.date.desc(), Transaction.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    return list(result.scalars().all()), total


async def get_transaction(db: AsyncSession, tx_id: uuid.UUID) -> Transaction | None:
    result = await db.execute(
        select(Transaction)
        .options(
            selectinload(Transaction.category),
            selectinload(Transaction.comments),
            selectinload(Transaction.receipts),
        )
        .where(Transaction.id == tx_id)
    )
    return result.scalar_one_or_none()


async def create_transaction(db: AsyncSession, data: TransactionCreate) -> Transaction:
    tx = Transaction(**data.model_dump())
    # Convert to base currency
    base = settings.base_currency
    if tx.currency.upper() != base.upper():
        tx.amount_base = await convert(float(tx.amount), tx.currency, base)
    else:
        tx.amount_base = float(tx.amount)
    db.add(tx)
    await db.flush()
    await _apply_balance(db, tx, +1)
    await db.flush()
    await db.refresh(tx)
    return tx


async def update_transaction(db: AsyncSession, tx: Transaction, data: TransactionUpdate) -> Transaction:
    await _apply_balance(db, tx, -1)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(tx, field, value)
    # Recalculate base amount if currency or amount changed
    base = settings.base_currency
    if tx.currency.upper() != base.upper():
        tx.amount_base = await convert(float(tx.amount), tx.currency, base)
    else:
        tx.amount_base = float(tx.amount)
    await db.flush()
    await _apply_balance(db, tx, +1)
    await db.flush()
    await db.refresh(tx)
    return tx


async def delete_transaction(db: AsyncSession, tx: Transaction) -> None:
    await _apply_balance(db, tx, -1)
    await db.delete(tx)
    await db.flush()
