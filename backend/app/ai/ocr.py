import base64
import json
import logging
import os
import uuid

from tenacity import retry, stop_after_attempt, wait_exponential

from app.ai.client import generate
from app.config import settings
from app.database import async_session_factory

logger = logging.getLogger(__name__)

PROMPT = """You are a receipt parser. Extract data from this receipt image and return
ONLY a JSON object:
{
  "merchant": "string or null",
  "date": "YYYY-MM-DD or null",
  "total_amount": number or null,
  "currency": "3-letter ISO code or null",
  "line_items": [{"name": "string", "quantity": number, "unit_price": number}]
}
Return valid JSON only. Use null for fields you cannot determine."""


def _to_jpeg(image_bytes: bytes, max_px: int = 1568) -> bytes:
    from PIL import Image
    import io
    img = Image.open(io.BytesIO(image_bytes))
    w, h = img.size
    if max(w, h) > max_px:
        ratio = max_px / max(w, h)
        img = img.resize((int(w * ratio), int(h * ratio)), Image.LANCZOS)
    if img.mode != "RGB":
        img = img.convert("RGB")
    out = io.BytesIO()
    img.save(out, format="JPEG")
    return out.getvalue()


def _pdf_to_jpeg(pdf_path: str) -> bytes:
    from pdf2image import convert_from_path
    import io
    pages = convert_from_path(pdf_path, first_page=1, last_page=1, dpi=150)
    out = io.BytesIO()
    pages[0].save(out, format="JPEG")
    return out.getvalue()


def _parse_json(text: str) -> dict:
    text = text.strip()
    if "```" in text:
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def _call_vision(image_bytes: bytes) -> dict:
    b64 = base64.standard_b64encode(image_bytes).decode()
    parts = [
        {"inline_data": {"mime_type": "image/jpeg", "data": b64}},
        {"text": PROMPT},
    ]
    text = await generate(parts, max_tokens=512, temperature=0)
    return _parse_json(text)


async def process_receipt_ocr(receipt_id: uuid.UUID) -> None:
    from sqlalchemy import select
    from app.models.receipt import Receipt

    async with async_session_factory() as db:
        result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
        receipt = result.scalar_one_or_none()
        if not receipt:
            return
        receipt.ocr_status = "processing"
        await db.commit()

        try:
            full_path = os.path.join(settings.receipts_dir, receipt.file_path)
            if receipt.mime_type == "application/pdf":
                image_bytes = _pdf_to_jpeg(full_path)
            else:
                with open(full_path, "rb") as f:
                    image_bytes = f.read()
                image_bytes = _to_jpeg(image_bytes)

            ocr_data = await _call_vision(image_bytes)

            async with async_session_factory() as db2:
                r2 = await db2.execute(select(Receipt).where(Receipt.id == receipt_id))
                receipt2 = r2.scalar_one_or_none()
                if receipt2:
                    receipt2.ocr_raw = ocr_data
                    receipt2.merchant = ocr_data.get("merchant")
                    receipt2.total_amount = ocr_data.get("total_amount")
                    receipt2.currency = ocr_data.get("currency")
                    receipt2.line_items = ocr_data.get("line_items", [])
                    if ocr_data.get("date"):
                        from datetime import date
                        try:
                            receipt2.receipt_date = date.fromisoformat(ocr_data["date"])
                        except ValueError:
                            pass
                    receipt2.ocr_status = "done"
                    await db2.commit()

        except Exception as e:
            logger.error(f"OCR failed for receipt {receipt_id}: {e}")
            async with async_session_factory() as db3:
                r3 = await db3.execute(select(Receipt).where(Receipt.id == receipt_id))
                receipt3 = r3.scalar_one_or_none()
                if receipt3:
                    receipt3.ocr_status = "failed"
                    await db3.commit()
