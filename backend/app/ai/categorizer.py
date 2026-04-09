import json
import logging
import uuid

from tenacity import retry, stop_after_attempt, wait_exponential

from app.ai.client import generate
from app.database import async_session_factory
from app.models.category import Category
from app.models.transaction import Transaction

logger = logging.getLogger(__name__)

PROMPT = """You are a personal finance transaction categorizer.
Given a transaction description and amount, return ONLY a JSON object:
{{"category": "<name>", "confidence": <0.0-1.0>}}

Choose from: Food & Dining, Transport, Housing, Health,
Entertainment, Shopping, Utilities, Education, Travel, Income, Transfer, Other.

Return valid JSON only, no explanation.

Description: "{description}" Amount: {amount}"""


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
        PROMPT.format(description=description, amount=amount),
        max_tokens=64, temperature=0,
    )
    return _parse_json(text)


async def categorize_and_save(tx_id: uuid.UUID, description: str, amount: float) -> None:
    try:
        result = await _call(description, amount)
        category_name = result.get("category", "Other")

        async with async_session_factory() as db:
            from sqlalchemy import select
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
