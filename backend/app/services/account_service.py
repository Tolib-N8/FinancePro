import uuid

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.account import Account
from app.models.transaction import Transaction
from app.schemas.account import AccountCreate, AccountUpdate
from app.services.exchange_service import convert


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
    account = await db.get(Account, account_id)
    if account is None:
        raise ValueError("Account not found")

    result = await db.execute(
        select(Transaction).where(
            or_(Transaction.account_id == account_id, Transaction.to_account_id == account_id)
        )
    )
    transactions = list(result.scalars().all())

    balance = 0.0
    for tx in transactions:
        amount = float(tx.amount)
        if tx.currency.upper() != account.currency.upper():
            amount = await convert(amount, tx.currency, account.currency)

        if tx.type == "income" and tx.account_id == account_id:
            balance += amount
        elif tx.type == "expense" and tx.account_id == account_id:
            balance -= amount
        elif tx.type == "transfer":
            if tx.account_id == account_id:
                balance -= amount
            if tx.to_account_id == account_id:
                balance += amount

    account.balance = balance
    await db.flush()
    return balance
