import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.transaction import Transaction
from app.schemas.account import AccountCreate, AccountUpdate


async def list_accounts(db: AsyncSession) -> list[Account]:
    result = await db.execute(select(Account).where(Account.is_active == True).order_by(Account.created_at))
    return list(result.scalars().all())


async def get_account(db: AsyncSession, account_id: uuid.UUID) -> Account | None:
    result = await db.execute(select(Account).where(Account.id == account_id))
    return result.scalar_one_or_none()


async def create_account(db: AsyncSession, data: AccountCreate) -> Account:
    account = Account(**data.model_dump())
    db.add(account)
    await db.flush()
    await db.refresh(account)
    return account


async def update_account(db: AsyncSession, account: Account, data: AccountUpdate) -> Account:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(account, field, value)
    await db.flush()
    await db.refresh(account)
    return account


async def delete_account(db: AsyncSession, account: Account) -> None:
    account.is_active = False
    await db.flush()


async def recalculate_balance(db: AsyncSession, account_id: uuid.UUID) -> float:
    income_q = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == "income")
    )
    expense_q = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == "expense")
    )
    transfer_in_q = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.to_account_id == account_id, Transaction.type == "transfer")
    )
    transfer_out_q = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.account_id == account_id, Transaction.type == "transfer")
    )

    income = Decimal(str(income_q.scalar()))
    expenses = Decimal(str(expense_q.scalar()))
    transfer_in = Decimal(str(transfer_in_q.scalar()))
    transfer_out = Decimal(str(transfer_out_q.scalar()))

    balance = float(income - expenses + transfer_in - transfer_out)
    result = await db.execute(select(Account).where(Account.id == account_id))
    account = result.scalar_one()
    account.balance = balance
    await db.flush()
    return balance
