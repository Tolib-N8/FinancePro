import json
import logging
from datetime import date
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.client import stream_generate
from app.config import settings
from app.models.chat import ChatMessage, ChatSession

logger = logging.getLogger(__name__)


async def _build_financial_snapshot(db: AsyncSession) -> str:
    from sqlalchemy import func, select
    from app.models.account import Account
    from app.models.transaction import Transaction

    today = date.today()
    first_day = today.replace(day=1)

    accounts_result = await db.execute(select(Account).where(Account.is_active == True))
    accounts = accounts_result.scalars().all()
    accounts_summary = " | ".join(f"{a.name}: {float(a.balance):.2f} {a.currency}" for a in accounts)
    total_net_worth = sum(float(a.balance) for a in accounts)

    income_q = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.type == "income", Transaction.date >= first_day)
    )
    expense_q = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0))
        .where(Transaction.type == "expense", Transaction.date >= first_day)
    )
    income = float(income_q.scalar())
    expenses = float(expense_q.scalar())

    return f"""Current date: {today.isoformat()}
Base currency: {settings.base_currency}
Total net worth: {total_net_worth:.2f} {settings.base_currency}
Accounts: {accounts_summary}
This month income: {income:.2f} | expenses: {expenses:.2f} | savings: {income - expenses:.2f}"""


async def stream_assistant_response(
    db: AsyncSession, session: ChatSession, user_content: str
) -> AsyncGenerator[str, None]:
    snapshot = await _build_financial_snapshot(db)
    system_prompt = f"""You are a personal finance assistant for a single user.
Answer questions about their finances concisely and accurately.

{snapshot}

Be helpful and actionable."""

    history = [
        {"role": msg.role, "content": msg.content}
        for msg in session.messages[-40:]
        if msg.role in ("user", "assistant")
    ]
    if not history or history[-1]["content"] != user_content:
        history.append({"role": "user", "content": user_content})

    full_response = ""
    try:
        async for text in stream_generate(history, system_prompt):
            full_response += text
            yield f"data: {json.dumps({'text': text})}\n\n"

        assistant_msg = ChatMessage(session_id=session.id, role="assistant", content=full_response)
        db.add(assistant_msg)

        # Auto-title on first message
        if not session.title and len(session.messages) <= 2:
            try:
                from app.ai.client import generate
                title = await generate(
                    f"Generate a 4-word title for this conversation. Return ONLY the title, no quotes, no punctuation: {user_content}",
                    max_tokens=32, temperature=0,
                )
                session.title = title.strip()[:100]
            except Exception:
                session.title = user_content[:50]

        await db.commit()
        yield "data: [DONE]\n\n"

    except Exception as e:
        logger.error(f"Assistant stream error: {e}")
        yield f"data: {json.dumps({'error': str(e)})}\n\n"
