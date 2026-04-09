import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import Auth, DBSession
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate
from app.schemas.transaction import PaginatedTransactions
from app.services import account_service, transaction_service

router = APIRouter(dependencies=[Auth])


@router.get("", response_model=list[AccountOut])
async def list_accounts(db: AsyncSession = DBSession):
    return await account_service.list_accounts(db)


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
async def create_account(data: AccountCreate, db: AsyncSession = DBSession):
    return await account_service.create_account(db, data)


@router.get("/{account_id}", response_model=AccountOut)
async def get_account(account_id: uuid.UUID, db: AsyncSession = DBSession):
    account = await account_service.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


@router.put("/{account_id}", response_model=AccountOut)
async def update_account(account_id: uuid.UUID, data: AccountUpdate, db: AsyncSession = DBSession):
    account = await account_service.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    return await account_service.update_account(db, account, data)


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(account_id: uuid.UUID, db: AsyncSession = DBSession):
    account = await account_service.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    await account_service.delete_account(db, account)


@router.get("/{account_id}/transactions", response_model=PaginatedTransactions)
async def get_account_transactions(
    account_id: uuid.UUID,
    page: int = 1,
    page_size: int = 50,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    db: AsyncSession = DBSession,
):
    items, total = await transaction_service.list_transactions(
        db, account_id=account_id, date_from=date_from, date_to=date_to, page=page, page_size=page_size
    )
    return {"items": items, "total": total, "page": page, "page_size": page_size}


@router.post("/{account_id}/recalculate", response_model=dict)
async def recalculate_balance(account_id: uuid.UUID, db: AsyncSession = DBSession):
    account = await account_service.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    balance = await account_service.recalculate_balance(db, account_id)
    return {"balance": balance}
