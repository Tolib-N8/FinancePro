import json
import logging
import uuid

from sqlalchemy import select
from tenacity import retry, stop_after_attempt, wait_exponential

from app.ai.client import generate
from app.database import async_session_factory
from app.models.category import Category
from app.models.transaction import Transaction

logger = logging.getLogger(__name__)

CATEGORIES = (
    "Food & Dining, Transport, Housing, Health, Entertainment, Shopping, "
    "Utilities, Education, Travel, Income, Transfer, Other"
)

PROMPT = """You are a personal finance transaction categorizer.
Given a transaction description and amount, return ONLY a JSON object:
{{"category": "<name>", "confidence": <0.0-1.0>}}

Choose from: {categories}.

Return valid JSON only, no explanation.

Description: "{description}" Amount: {amount}"""

BATCH_PROMPT = """You are a personal finance transaction categorizer.
Categorize EACH numbered transaction below.

Valid categories: {categories}.

Return ONLY a JSON array, one object per transaction, in the same order:
[{{"index": <number>, "category": "<one valid category>"}}]

Transactions:
{items}"""

# How many transactions to categorize per AI call. Keeps each request small
# and the whole import down to a couple of calls instead of one-per-row.
BATCH_SIZE = 80


def _parse_json(text: str) -> dict:
    text = text.strip()
    if "```" in text:
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def _call(description: str, amount: float) -> dict:
    text = await generate(
        PROMPT.format(categories=CATEGORIES, description=description, amount=amount),
        max_tokens=64, temperature=0,
    )
    return _parse_json(text)


async def categorize_and_save(tx_id: uuid.UUID, description: str, amount: float) -> None:
    try:
        result = await _call(description, amount)
        category_name = result.get("category", "Other")

        async with async_session_factory() as db:
            cat_result = await db.execute(select(Category).where(Category.name == category_name))
            category = cat_result.scalar_one_or_none()
            if not category:
                cat_result = await db.execute(select(Category).where(Category.name == "Other"))
                category = cat_result.scalar_one_or_none()

            tx_result = await db.execute(select(Transaction).where(Transaction.id == tx_id))
            tx = tx_result.scalar_one_or_none()
            if tx and category:
                tx.category_id = category.id
                tx.ai_categorized = True
                await db.commit()
    except Exception as e:
        logger.error(f"Categorization failed for tx {tx_id}: {e}")


async def categorize_batch(items: list[tuple[uuid.UUID, str, float]]) -> None:
    """Categorize many transactions with a few AI calls instead of one per row.

    Used after a bulk statement import — firing one Gemini call per imported
    transaction saturates the free-tier rate limit (429 storm). This chunks
    the work so a 100-row statement costs ~2 calls, not 100.
    """
    for start in range(0, len(items), BATCH_SIZE):
        await _categorize_chunk(items[start:start + BATCH_SIZE])


async def _categorize_chunk(chunk: list[tuple[uuid.UUID, str, float]]) -> None:
    if not chunk:
        return
    listing = "\n".join(
        f'{i}. "{desc}" (amount: {amount})'
        for i, (_, desc, amount) in enumerate(chunk)
    )
    try:
        text = await generate(
            BATCH_PROMPT.format(categories=CATEGORIES, items=listing),
            max_tokens=8192,
            temperature=0,
            response_mime_type="application/json",
        )
        parsed = json.loads(text.strip())
        rows = parsed if isinstance(parsed, list) else parsed.get("transactions", [])
    except Exception as e:
        logger.error(f"Batch categorization failed for {len(chunk)} rows: {e}")
        return

    by_index: dict[int, str] = {}
    for row in rows:
        try:
            by_index[int(row["index"])] = str(row["category"])
        except (KeyError, ValueError, TypeError):
            continue

    try:
        async with async_session_factory() as db:
            cats = (await db.execute(select(Category))).scalars().all()
            cat_by_name = {c.name: c for c in cats}
            fallback = cat_by_name.get("Other")

            for i, (tx_id, _, _) in enumerate(chunk):
                category = cat_by_name.get(by_index.get(i, ""), fallback)
                if category is None:
                    continue
                tx = (
                    await db.execute(select(Transaction).where(Transaction.id == tx_id))
                ).scalar_one_or_none()
                if tx is not None:
                    tx.category_id = category.id
                    tx.ai_categorized = True
            await db.commit()
    except Exception as e:
        logger.error(f"Batch categorization DB update failed: {e}")
