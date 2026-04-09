import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import Auth, DBSession
from app.models.comment import Comment
from app.schemas.comment import CommentCreate, CommentOut, CommentUpdate
from app.schemas.transaction import (
    PaginatedTransactions,
    TransactionCreate,
    TransactionDetail,
    TransactionOut,
    TransactionUpdate,
)
from app.services import transaction_service

router = APIRouter(dependencies=[Auth])


@router.get("", response_model=PaginatedTransactions)
async def list_transactions(
    account_id: Optional[uuid.UUID] = None,
    category_id: Optional[uuid.UUID] = None,
    type: Optional[str] = None,
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 50,
    db: AsyncSession = DBSession,
):
    items, total = await transaction_service.list_transactions(
        db,
        account_id=account_id,
        category_id=category_id,
        tx_type=type,
        date_from=date_from,
        date_to=date_to,
        search=search,
        page=page,
        page_size=page_size,
    )
    return {"items": items, "total": total, "page": page, "page_size": page_size}


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    data: TransactionCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = DBSession,
):
    tx = await transaction_service.create_transaction(db, data)
    if not tx.category_id and tx.description:
        background_tasks.add_task(_categorize_transaction, tx.id, tx.description, float(tx.amount))
    # Reload with eager-loaded relationships to avoid lazy-load errors
    tx = await transaction_service.get_transaction(db, tx.id)
    return tx


@router.get("/{tx_id}", response_model=TransactionDetail)
async def get_transaction(tx_id: uuid.UUID, db: AsyncSession = DBSession):
    tx = await transaction_service.get_transaction(db, tx_id)
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return tx


@router.put("/{tx_id}", response_model=TransactionOut)
async def update_transaction(
    tx_id: uuid.UUID,
    data: TransactionUpdate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = DBSession,
):
    tx = await transaction_service.get_transaction(db, tx_id)
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    updated = await transaction_service.update_transaction(db, tx, data)
    if data.description and not data.category_id:
        background_tasks.add_task(_categorize_transaction, tx_id, data.description, float(updated.amount))
    # Reload with eager-loaded relationships
    return await transaction_service.get_transaction(db, tx_id)


@router.delete("/{tx_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(tx_id: uuid.UUID, db: AsyncSession = DBSession):
    tx = await transaction_service.get_transaction(db, tx_id)
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    await transaction_service.delete_transaction(db, tx)


@router.post("/{tx_id}/categorize", response_model=dict)
async def manual_categorize(tx_id: uuid.UUID, background_tasks: BackgroundTasks, db: AsyncSession = DBSession):
    tx = await transaction_service.get_transaction(db, tx_id)
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    if tx.description:
        background_tasks.add_task(_categorize_transaction, tx_id, tx.description, float(tx.amount))
    return {"status": "categorization queued"}


# Comments
@router.get("/{tx_id}/comments", response_model=list[CommentOut])
async def list_comments(tx_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(select(Comment).where(Comment.transaction_id == tx_id).order_by(Comment.created_at))
    return list(result.scalars().all())


@router.post("/{tx_id}/comments", response_model=CommentOut, status_code=status.HTTP_201_CREATED)
async def create_comment(tx_id: uuid.UUID, data: CommentCreate, db: AsyncSession = DBSession):
    comment = Comment(transaction_id=tx_id, body=data.body)
    db.add(comment)
    await db.flush()
    await db.refresh(comment)
    return comment


@router.put("/{tx_id}/comments/{comment_id}", response_model=CommentOut)
async def update_comment(tx_id: uuid.UUID, comment_id: uuid.UUID, data: CommentUpdate, db: AsyncSession = DBSession):
    result = await db.execute(
        select(Comment).where(Comment.id == comment_id, Comment.transaction_id == tx_id)
    )
    comment = result.scalar_one_or_none()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    if data.body is not None:
        comment.body = data.body
    await db.flush()
    await db.refresh(comment)
    return comment


@router.delete("/{tx_id}/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_comment(tx_id: uuid.UUID, comment_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(
        select(Comment).where(Comment.id == comment_id, Comment.transaction_id == tx_id)
    )
    comment = result.scalar_one_or_none()
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    await db.delete(comment)
    await db.flush()


async def _categorize_transaction(tx_id: uuid.UUID, description: str, amount: float) -> None:
    from app.ai.categorizer import categorize_and_save
    await categorize_and_save(tx_id, description, amount)
