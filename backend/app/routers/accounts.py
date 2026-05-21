import uuid
from datetime import date
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException, UploadFile, status
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import Auth, DBSession
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate
from app.schemas.statement import StatementImportResult, StatementImportSample
from app.schemas.transaction import TransactionCreate
from app.schemas.transaction import PaginatedTransactions
from app.services import account_service, statement_import_service, transaction_service
from app.models.transaction import Transaction

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


@router.post("/{account_id}/import-statement", response_model=StatementImportResult)
async def import_statement(
    account_id: uuid.UUID,
    file: UploadFile,
    background_tasks: BackgroundTasks,
    db: AsyncSession = DBSession,
):
    account = await account_service.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    if not statement_import_service.is_supported_statement_file(file.filename, file.content_type):
        raise HTTPException(status_code=400, detail="Unsupported statement format")

    try:
        entries = await statement_import_service.parse_statement_entries(
            await file.read(),
            file.filename,
            file.content_type,
            account.currency,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    dates = [entry.date for entry in entries]
    existing_result = await db.execute(
        select(Transaction).where(
            and_(
                Transaction.account_id == account_id,
                Transaction.date >= min(dates),
                Transaction.date <= max(dates),
            )
        )
    )

    # Signatures of transactions already in the DB — used to skip rows when the
    # same statement is imported twice. We deliberately do NOT add freshly
    # imported rows back into this set: a single statement can legitimately
    # contain several transactions with an identical date/type/amount/
    # description (each a distinct bank operation), and those must all import.
    existing_signatures = {
        _tx_signature(tx.date, tx.type, float(tx.amount), tx.currency, tx.description)
        for tx in existing_result.scalars().all()
    }

    imported: list[StatementImportSample] = []
    to_categorize: list[tuple[uuid.UUID, str, float]] = []
    skipped_duplicates = 0

    for entry in entries:
        signature = _tx_signature(
            entry.date,
            entry.tx_type,
            entry.amount,
            entry.currency,
            entry.description,
        )
        if signature in existing_signatures:
            skipped_duplicates += 1
            continue

        tx = await transaction_service.create_transaction(
            db,
            TransactionCreate(
                account_id=account_id,
                type=entry.tx_type,
                amount=entry.amount,
                currency=entry.currency,
                date=entry.date,
                description=entry.description,
                category_id=None,
                is_recurring=False,
            ),
        )
        imported.append(
            StatementImportSample(
                date=entry.date,
                type=entry.tx_type,
                amount=entry.amount,
                currency=entry.currency,
                description=entry.description,
            )
        )
        if entry.description:
            to_categorize.append((tx.id, entry.description, entry.amount))

    # One batched categorization task for the whole import — firing a separate
    # AI call per row would saturate the Gemini rate limit (429 storm).
    if to_categorize:
        background_tasks.add_task(_categorize_imported, to_categorize)

    return StatementImportResult(
        account_id=account_id,
        parsed_count=len(entries),
        imported_count=len(imported),
        skipped_duplicates=skipped_duplicates,
        sample=imported[:10],
    )


def _tx_signature(
    tx_date: date,
    tx_type: str,
    amount: float,
    currency: str,
    description: str | None,
) -> tuple[str, str, str, str, str]:
    normalized_description = " ".join((description or "").strip().lower().split())
    return (
        tx_date.isoformat(),
        tx_type,
        f"{amount:.2f}",
        currency.upper(),
        normalized_description,
    )


async def _categorize_imported(items: list[tuple[uuid.UUID, str, float]]) -> None:
    """Background task: categorize a whole statement import in batched AI calls."""
    from app.ai.categorizer import categorize_batch

    await categorize_batch(items)
