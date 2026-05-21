import base64
import csv
import io
import json
import logging
import re
import subprocess
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import httpx
from dateutil import parser as date_parser
from tenacity import RetryError, retry, stop_after_attempt, wait_exponential

from app.ai.client import generate

logger = logging.getLogger(__name__)

SUPPORTED_EXTENSIONS = {".csv", ".txt", ".pdf", ".jpg", ".jpeg", ".png", ".webp"}
TABULAR_MIME = {
    "text/csv",
    "application/csv",
    "text/plain",
    "application/vnd.ms-excel",
}
IMAGE_MIME = {"image/jpeg", "image/png", "image/webp"}
PDF_MIME = {"application/pdf"}

HEADER_ALIASES = {
    "date": {
        "date",
        "bookingdate",
        "transactiondate",
        "operationdate",
        "valuedate",
        "дата",
        "датаоперации",
        "дататранзакции",
        "датаплатежа",
    },
    "description": {
        "description",
        "details",
        "purpose",
        "merchant",
        "counterparty",
        "payee",
        "memo",
        "note",
        "comment",
        "назначение",
        "описание",
        "контрагент",
        "получатель",
        "операция",
        "магазин",
    },
    "amount": {
        "amount",
        "sum",
        "value",
        "сумма",
        "итого",
    },
    "debit": {
        "debit",
        "withdrawal",
        "outflow",
        "expense",
        "списание",
        "расход",
        "дебет",
    },
    "credit": {
        "credit",
        "deposit",
        "inflow",
        "income",
        "поступление",
        "приход",
        "кредит",
    },
    "currency": {
        "currency",
        "curr",
        "валюта",
    },
}

STATEMENT_PROMPT = """You are a bank statement parser.
Extract ONLY real transaction rows from the provided bank statement.

Return ONLY valid JSON in this exact shape:
{{
  "transactions": [
    {{
      "date": "YYYY-MM-DD",
      "description": "short transaction description",
      "amount": 123.45,
      "currency": "USD",
      "direction": "debit"
    }}
  ]
}}

Rules:
- Include only transaction rows. Skip opening balance, closing balance, totals, fees summary, headers, and page footers.
- "direction" means: debit = money out, credit = money in.
- "amount" must always be a positive number.
- If currency is missing, use "{account_currency}".
- If a row is unreadable or incomplete, skip it.
- Do not invent transactions.
- Return JSON only, with no markdown.
"""


@dataclass(slots=True)
class ParsedStatementEntry:
    date: date
    amount: float
    tx_type: str
    description: str
    currency: str


def is_supported_statement_file(filename: str | None, content_type: str | None) -> bool:
    ext = Path(filename or "").suffix.lower()
    content_type = (content_type or "").lower()
    return ext in SUPPORTED_EXTENSIONS or content_type in TABULAR_MIME | IMAGE_MIME | PDF_MIME


async def parse_statement_entries(
    file_bytes: bytes,
    filename: str | None,
    content_type: str | None,
    account_currency: str,
) -> list[ParsedStatementEntry]:
    if not file_bytes:
        raise ValueError("Empty statement file")

    ext = Path(filename or "").suffix.lower()
    content_type = (content_type or "").lower()

    try:
        if ext in {".csv", ".txt"} or content_type in TABULAR_MIME:
            entries = await _parse_tabular_statement(file_bytes, account_currency)
        elif ext == ".pdf" or content_type in PDF_MIME:
            # Prefer the PDF's embedded text layer — a deterministic parse uses
            # no AI quota at all. Fall back to Gemini vision only for scanned
            # PDFs (no text layer) or layouts the text parser doesn't know.
            entries = _parse_pdf_text_layer(file_bytes)
            if not entries:
                entries = await _parse_binary_statement_with_ai(
                    file_bytes, "pdf", account_currency
                )
        elif ext in {".jpg", ".jpeg", ".png", ".webp"} or content_type in IMAGE_MIME:
            entries = await _parse_binary_statement_with_ai(file_bytes, "image", account_currency)
        else:
            raise ValueError("Unsupported statement format")
    except ValueError:
        raise
    except RuntimeError as exc:
        # gemini_url() raises this when GEMINI_API_KEY is unset — surface to the user.
        raise ValueError(str(exc)) from exc
    except (httpx.HTTPError, json.JSONDecodeError, RetryError) as exc:
        logger.exception("Statement AI parse failed")
        raise ValueError(
            "Could not read this statement automatically — try exporting as CSV "
            "with a header row (Date, Description, Amount, Currency)."
        ) from exc

    if not entries:
        raise ValueError("No transactions found in statement")
    return entries


async def _parse_tabular_statement(file_bytes: bytes, account_currency: str) -> list[ParsedStatementEntry]:
    text = _decode_text(file_bytes)
    sample = text[:4096]

    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t|")
        reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    except csv.Error:
        reader = csv.DictReader(io.StringIO(text), delimiter=";")
    fieldnames = [field or "" for field in reader.fieldnames or []]
    if not fieldnames:
        raise ValueError("Statement file must contain a header row")

    date_key = _find_header(fieldnames, "date")
    description_key = _find_header(fieldnames, "description")
    amount_key = _find_header(fieldnames, "amount")
    debit_key = _find_header(fieldnames, "debit")
    credit_key = _find_header(fieldnames, "credit")
    currency_key = _find_header(fieldnames, "currency")

    if not date_key or not (amount_key or debit_key or credit_key):
        return await _parse_text_statement_with_ai(text, account_currency)

    entries: list[ParsedStatementEntry] = []
    for row in reader:
        entry_date = _parse_date(row.get(date_key))
        if not entry_date:
            continue

        amount_data = _resolve_amount(row, amount_key, debit_key, credit_key)
        if not amount_data:
            continue
        amount, tx_type = amount_data

        description = _pick_description(row, description_key)
        currency = _normalize_currency(row.get(currency_key), account_currency)

        entries.append(
            ParsedStatementEntry(
                date=entry_date,
                amount=amount,
                tx_type=tx_type,
                description=description,
                currency=currency,
            )
        )

    return entries


async def _parse_text_statement_with_ai(text: str, account_currency: str) -> list[ParsedStatementEntry]:
    parts = [
        {"text": STATEMENT_PROMPT.format(account_currency=account_currency)},
        {"text": text[:40000]},
    ]
    data = await _call_statement_ai(parts)
    return _entries_from_ai_payload(data, account_currency)


# --- Deterministic PDF text-layer parsing (no AI quota used) ---------------

# Anchor row of an Alif Mobi statement: long numeric ID, then the Приход /
# Расход / Комиссия amount columns, then a 3-letter currency code.
_ALIF_ANCHOR_RE = re.compile(
    r"^\s*(\d{6,})\s+([\d.,]+)\s+([\d.,]+)\s+([\d.,]+)\s+([A-Za-z]{3})\b"
)
_ALIF_DATE_RE = re.compile(r"(\d{1,2}\.\d{1,2}\.\d{4})")


def _extract_pdf_text(pdf_bytes: bytes) -> str:
    """Extract a PDF's embedded text layer via poppler's pdftotext.

    Returns '' for scanned PDFs (no text layer) or if pdftotext is missing.
    """
    try:
        result = subprocess.run(
            ["pdftotext", "-layout", "-enc", "UTF-8", "-", "-"],
            input=pdf_bytes,
            capture_output=True,
            timeout=30,
        )
    except (subprocess.SubprocessError, FileNotFoundError) as exc:
        logger.warning("pdftotext unavailable or failed: %s", exc)
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.decode("utf-8", errors="ignore")


def _parse_alif_text(text: str) -> list[ParsedStatementEntry]:
    """Parse an Alif Mobi statement from its extracted text layer.

    The table has one transaction per multi-line block: a date line, the
    anchor line (ID + amount columns + currency), then a time line. Returns
    [] if the text does not look like this format.
    """
    lines = text.splitlines()

    header_idx: int | None = None
    for idx, line in enumerate(lines):
        low = line.lower()
        if "приход" in low and "расход" in low and "валюта" in low:
            header_idx = idx
            break
    if header_idx is None:
        return []

    entries: list[ParsedStatementEntry] = []
    for i in range(header_idx + 1, len(lines)):
        anchor = _ALIF_ANCHOR_RE.match(lines[i])
        if not anchor:
            continue
        _tx_id, prihod_s, rashod_s, _fee_s, currency = anchor.groups()

        prihod = _parse_amount(prihod_s) or 0.0
        rashod = _parse_amount(rashod_s) or 0.0
        if prihod > 0:
            amount, tx_type = prihod, "income"
        elif rashod > 0:
            amount, tx_type = rashod, "expense"
        else:
            continue

        # The date sits on one of the few lines above the anchor.
        entry_date: date | None = None
        date_tail = ""
        for j in range(i - 1, max(header_idx, i - 4) - 1, -1):
            dm = _ALIF_DATE_RE.search(lines[j])
            if dm:
                entry_date = _parse_date(dm.group(1))
                date_tail = lines[j][dm.end():].strip()
                break
        if not entry_date:
            continue

        # Description = worded text after the date, plus any worded tokens on
        # the anchor line (skipping phone numbers, card masks and numeric IDs).
        desc_bits: list[str] = []
        if date_tail:
            desc_bits.append(date_tail)
        for token in lines[i][anchor.end():].split():
            if token.startswith("+") or "*" in token or token.isdigit():
                continue
            if any(ch.isalpha() for ch in token):
                desc_bits.append(token)
        description = " ".join(desc_bits).strip()[:255] or "Imported from statement"

        entries.append(
            ParsedStatementEntry(
                date=entry_date,
                amount=amount,
                tx_type=tx_type,
                description=description,
                currency=currency.upper(),
            )
        )
    return entries


def _parse_pdf_text_layer(pdf_bytes: bytes) -> list[ParsedStatementEntry]:
    """Try to parse a PDF deterministically from its text layer (no AI).

    Returns [] when the PDF has no text layer or an unrecognised layout, so
    the caller falls back to Gemini vision.
    """
    text = _extract_pdf_text(pdf_bytes)
    if not text.strip():
        return []
    return _parse_alif_text(text)


async def _parse_binary_statement_with_ai(
    file_bytes: bytes,
    file_kind: str,
    account_currency: str,
) -> list[ParsedStatementEntry]:
    if file_kind == "pdf":
        image_bytes = _pdf_to_jpegs(file_bytes, max_pages=20)
    else:
        image_bytes = [_to_jpeg(file_bytes)]

    # Send the whole document in ONE AI call. The free Gemini tier rate-limits
    # aggressively (429) the moment several requests overlap, so splitting a
    # statement into per-page calls is far slower than a single request.
    # Truncation of a long response is handled two ways: a large output-token
    # budget (see _call_statement_ai), and _parse_json salvaging complete rows
    # out of a response that still got cut off.
    parts: list[dict] = [
        {
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64.standard_b64encode(image).decode(),
            }
        }
        for image in image_bytes
    ]
    parts.append({"text": STATEMENT_PROMPT.format(account_currency=account_currency)})

    data = await _call_statement_ai(parts)
    return _entries_from_ai_payload(data, account_currency)


def _decode_text(file_bytes: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "cp1251", "latin-1"):
        try:
            return file_bytes.decode(encoding)
        except UnicodeDecodeError:
            continue
    return file_bytes.decode("utf-8", errors="ignore")


def _normalize_header(text: str) -> str:
    return re.sub(r"[^a-zа-я0-9]+", "", text.lower())


def _find_header(fieldnames: list[str], kind: str) -> str | None:
    aliases = HEADER_ALIASES[kind]
    normalized = {_normalize_header(name): name for name in fieldnames}

    for alias in aliases:
        if alias in normalized:
            return normalized[alias]

    for key, original in normalized.items():
        if any(alias in key or key in alias for alias in aliases):
            return original
    return None


_ISO_DATE_RE = re.compile(r"^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}(?:[T\s].*)?$")


def _parse_date(value: object) -> date | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    # ISO-style "YYYY-MM-DD" (or YYYY/MM/DD, YYYY.MM.DD) is unambiguous — parse
    # year-first so dateutil doesn't flip month/day when both are <= 12.
    # Everything else (e.g. "01/05/2026", "15.01.2024") is treated as day-first
    # which matches European / Russian bank statements.
    dayfirst = not bool(_ISO_DATE_RE.match(text))
    try:
        return date_parser.parse(text, dayfirst=dayfirst, fuzzy=True).date()
    except (ValueError, TypeError, OverflowError):
        return None


def _parse_amount(value: object) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None

    negative = False
    if text.startswith("(") and text.endswith(")"):
        negative = True
        text = text[1:-1]

    text = (
        text.replace("\u00a0", "")
        .replace(" ", "")
        .replace("−", "-")
        .replace("–", "-")
    )
    text = re.sub(r"[^0-9,.\-]", "", text)
    if not text:
        return None

    if text.endswith("-"):
        negative = True
        text = text[:-1]

    if text.count(",") and text.count("."):
        if text.rfind(",") > text.rfind("."):
            text = text.replace(".", "").replace(",", ".")
        else:
            text = text.replace(",", "")
    elif text.count(",") and not text.count("."):
        text = text.replace(",", ".")

    try:
        amount = float(text)
    except ValueError:
        return None

    if negative and amount > 0:
        amount *= -1
    return amount


def _looks_numeric_value(value: str) -> bool:
    cleaned = (
        value.strip()
        .replace("\u00a0", "")
        .replace(" ", "")
        .replace("−", "-")
        .replace("–", "-")
    )
    cleaned = re.sub(r"[A-Za-zА-Яа-я$€£¥₽₸₴₾₼₮₱₹]", "", cleaned)
    cleaned = re.sub(r"[^0-9,.\-()]", "", cleaned)
    return bool(cleaned) and _parse_amount(cleaned) is not None


def _resolve_amount(
    row: dict[str, object],
    amount_key: str | None,
    debit_key: str | None,
    credit_key: str | None,
) -> tuple[float, str] | None:
    if amount_key:
        amount = _parse_amount(row.get(amount_key))
        if amount is None or amount == 0:
            return None
        if amount < 0:
            return abs(amount), "expense"
        return amount, "income"

    debit = _parse_amount(row.get(debit_key)) if debit_key else None
    credit = _parse_amount(row.get(credit_key)) if credit_key else None

    if debit and abs(debit) > 0:
        return abs(debit), "expense"
    if credit and abs(credit) > 0:
        return abs(credit), "income"
    return None


def _pick_description(row: dict[str, object], description_key: str | None) -> str:
    if description_key:
        text = str(row.get(description_key) or "").strip()
        if text:
            return text[:255]

    for key, value in row.items():
        normalized_key = _normalize_header(key)
        if normalized_key in HEADER_ALIASES["date"] | HEADER_ALIASES["amount"] | HEADER_ALIASES["debit"] | HEADER_ALIASES["credit"] | HEADER_ALIASES["currency"]:
            continue
        text = str(value or "").strip()
        if text and not _looks_numeric_value(text):
            return text[:255]

    return "Imported from statement"


def _normalize_currency(value: object, fallback: str) -> str:
    text = re.sub(r"[^A-Za-z]", "", str(value or "")).upper()
    if len(text) == 3:
        return text
    return fallback.upper()


def _to_jpeg(image_bytes: bytes, max_px: int = 1568) -> bytes:
    from PIL import Image, UnidentifiedImageError

    try:
        image = Image.open(io.BytesIO(image_bytes))
        image.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError("File is not a valid image") from exc
    width, height = image.size
    if max(width, height) > max_px:
        ratio = max_px / max(width, height)
        image = image.resize((int(width * ratio), int(height * ratio)), Image.LANCZOS)
    if image.mode != "RGB":
        image = image.convert("RGB")

    out = io.BytesIO()
    image.save(out, format="JPEG", quality=85)
    return out.getvalue()


def _pdf_to_jpegs(pdf_bytes: bytes, max_pages: int = 8) -> list[bytes]:
    from pdf2image import convert_from_bytes
    from pdf2image.exceptions import PDFPageCountError, PDFSyntaxError

    try:
        pages = convert_from_bytes(pdf_bytes, dpi=140, first_page=1, last_page=max_pages)
    except (PDFPageCountError, PDFSyntaxError) as exc:
        raise ValueError("File is not a valid PDF") from exc

    output: list[bytes] = []
    for page in pages:
        out = io.BytesIO()
        if page.mode != "RGB":
            page = page.convert("RGB")
        page.save(out, format="JPEG", quality=85)
        output.append(out.getvalue())
    return output


def _salvage_transactions(text: str) -> list[dict]:
    """Pull every complete JSON object out of a possibly-truncated array.

    When a long Gemini response is cut off at maxOutputTokens the outer JSON
    never closes, so a strict parse fails. The individual transaction objects
    before the cut are still valid — extract those rather than losing the
    whole import.
    """
    decoder = json.JSONDecoder()
    objects: list[dict] = []
    i = text.find("[")
    if i < 0:
        return objects
    i += 1
    while i < len(text):
        while i < len(text) and text[i] in " \t\r\n,":
            i += 1
        if i >= len(text) or text[i] != "{":
            break
        try:
            obj, end = decoder.raw_decode(text, i)
        except json.JSONDecodeError:
            break
        if isinstance(obj, dict):
            objects.append(obj)
        i = end
    return objects


def _parse_json(text: str) -> dict:
    """Extract the first JSON object/array from an LLM response.

    Gemini sometimes returns the JSON wrapped in ```json fences, prefixed with
    chatter, or followed by trailing tokens. We strip code fences and use
    raw_decode so trailing characters don't break parsing. If the response was
    truncated mid-array, salvage the complete transaction objects.
    """
    cleaned = text.strip()
    if "```" in cleaned:
        # Pull the first fenced block that looks like JSON.
        for part in cleaned.split("```"):
            stripped = part.strip()
            if stripped.startswith("json"):
                cleaned = stripped[4:].lstrip()
                break
            if stripped.startswith("{") or stripped.startswith("["):
                cleaned = stripped
                break

    decoder = json.JSONDecoder()
    start = min(
        (i for i in (cleaned.find("{"), cleaned.find("[")) if i >= 0),
        default=-1,
    )
    if start < 0:
        raise json.JSONDecodeError("No JSON object found in response", cleaned, 0)

    try:
        obj, _ = decoder.raw_decode(cleaned[start:])
    except json.JSONDecodeError:
        # Response was likely truncated — recover the rows parsed so far.
        salvaged = _salvage_transactions(cleaned[start:])
        if salvaged:
            logger.warning(
                "Statement JSON truncated — salvaged %d transaction rows", len(salvaged)
            )
            return {"transactions": salvaged}
        raise

    if isinstance(obj, list):
        return {"transactions": obj}
    if not isinstance(obj, dict):
        raise json.JSONDecodeError("Expected JSON object", cleaned, 0)
    return obj


@retry(stop=stop_after_attempt(2), wait=wait_exponential(multiplier=1, min=2, max=8), reraise=False)
async def _call_statement_ai(parts: list[dict]) -> dict:
    # 32k output headroom so a dense page of transactions is never truncated
    # mid-JSON (which would surface as a JSONDecodeError).
    text = await generate(
        parts,
        max_tokens=32768,
        temperature=0,
        response_mime_type="application/json",
    )
    return _parse_json(text)


def _entries_from_ai_payload(payload: dict, account_currency: str) -> list[ParsedStatementEntry]:
    raw_items = payload.get("transactions", [])
    entries: list[ParsedStatementEntry] = []

    for item in raw_items:
        entry_date = _parse_date(item.get("date"))
        amount = _parse_amount(item.get("amount"))
        if not entry_date or amount is None or amount == 0:
            continue

        direction = str(item.get("direction") or item.get("type") or "").strip().lower()
        if not direction:
            direction = "expense" if amount < 0 else "income"

        if direction in {"debit", "expense", "out", "withdrawal"}:
            tx_type = "expense"
        else:
            tx_type = "income"

        description = str(item.get("description") or "").strip()[:255] or "Imported from statement"
        currency = _normalize_currency(item.get("currency"), account_currency)

        entries.append(
            ParsedStatementEntry(
                date=entry_date,
                amount=abs(amount),
                tx_type=tx_type,
                description=description,
                currency=currency,
            )
        )

    return entries
