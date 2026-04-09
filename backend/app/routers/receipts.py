import os
import uuid
from pathlib import Path

import aiofiles
from fastapi import APIRouter, BackgroundTasks, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.dependencies import Auth, DBSession
from app.models.receipt import Receipt
from app.schemas.receipt import ReceiptOut

router = APIRouter(dependencies=[Auth])

ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp", "application/pdf"}


@router.post("/upload", response_model=ReceiptOut, status_code=status.HTTP_201_CREATED)
async def upload_receipt(file: UploadFile, background_tasks: BackgroundTasks, db: AsyncSession = DBSession):
    if file.content_type not in ALLOWED_MIME:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {file.content_type}")

    receipt_id = uuid.uuid4()
    ext = Path(file.filename or "receipt").suffix or ".jpg"
    file_path = f"{receipt_id}{ext}"
    full_path = os.path.join(settings.receipts_dir, file_path)

    os.makedirs(settings.receipts_dir, exist_ok=True)
    async with aiofiles.open(full_path, "wb") as f:
        content = await file.read()
        await f.write(content)

    receipt = Receipt(
        id=receipt_id,
        file_path=file_path,
        file_name=file.filename or "receipt",
        mime_type=file.content_type,
        ocr_status="pending",
    )
    db.add(receipt)
    await db.flush()
    await db.refresh(receipt)

    background_tasks.add_task(_run_ocr, receipt_id)
    return receipt


@router.get("/{receipt_id}", response_model=ReceiptOut)
async def get_receipt(receipt_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=404, detail="Receipt not found")
    return receipt


@router.post("/{receipt_id}/link/{tx_id}", response_model=ReceiptOut)
async def link_receipt(receipt_id: uuid.UUID, tx_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=404, detail="Receipt not found")
    receipt.transaction_id = tx_id
    await db.flush()
    await db.refresh(receipt)
    return receipt


@router.get("/{receipt_id}/file")
async def serve_receipt(receipt_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=404, detail="Receipt not found")
    full_path = os.path.join(settings.receipts_dir, receipt.file_path)
    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="File not found on disk")
    return FileResponse(full_path, media_type=receipt.mime_type, filename=receipt.file_name)


@router.delete("/{receipt_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_receipt(receipt_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=404, detail="Receipt not found")
    full_path = os.path.join(settings.receipts_dir, receipt.file_path)
    if os.path.exists(full_path):
        os.remove(full_path)
    await db.delete(receipt)
    await db.flush()


async def _run_ocr(receipt_id: uuid.UUID) -> None:
    from app.ai.ocr import process_receipt_ocr
    await process_receipt_ocr(receipt_id)
