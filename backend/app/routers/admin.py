import csv
import io
from datetime import date
from typing import Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.dependencies import Auth, DBSession
from app.models.transaction import Transaction
from app.services.exchange_service import convert

router = APIRouter(dependencies=[Auth])


@router.post("/fix-amount-base", response_model=dict)
async def fix_amount_base(db: AsyncSession = DBSession):
    """Recalculate amount_base for all transactions where it is NULL."""
    result = await db.execute(
        select(Transaction).where(Transaction.amount_base.is_(None))
    )
    transactions = list(result.scalars().all())
    base = settings.base_currency
    fixed = 0

    for tx in transactions:
        if tx.currency.upper() == base.upper():
            tx.amount_base = float(tx.amount)
        else:
            tx.amount_base = await convert(float(tx.amount), tx.currency, base)
        fixed += 1

    await db.flush()
    return {"fixed": fixed, "base_currency": base}


@router.get("/export/csv")
async def export_csv(
    date_from: Optional[date] = None,
    date_to: Optional[date] = None,
    type: Optional[str] = None,
    db: AsyncSession = DBSession,
):
    """Export transactions as CSV file."""
    query = (
        select(Transaction)
        .options(selectinload(Transaction.category))
        .order_by(Transaction.date.desc(), Transaction.created_at.desc())
    )
    if date_from:
        query = query.where(Transaction.date >= date_from)
    if date_to:
        query = query.where(Transaction.date <= date_to)
    if type:
        query = query.where(Transaction.type == type)

    result = await db.execute(query)
    transactions = list(result.scalars().all())

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Date", "Type", "Amount", "Currency", "Amount (Base)",
        "Category", "Description", "Account ID",
    ])
    for tx in transactions:
        writer.writerow([
            tx.date.isoformat(),
            tx.type,
            float(tx.amount),
            tx.currency,
            float(tx.amount_base) if tx.amount_base else "",
            tx.category.name if tx.category else "",
            tx.description or "",
            str(tx.account_id),
        ])

    output.seek(0)
    filename = f"financepro_transactions"
    if date_from:
        filename += f"_from_{date_from.isoformat()}"
    if date_to:
        filename += f"_to_{date_to.isoformat()}"
    filename += ".csv"

    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
