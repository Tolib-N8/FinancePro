from datetime import date, timedelta

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.category import Category
from app.models.transaction import Transaction


async def get_monthly_summary(db: AsyncSession, month: date) -> dict:
    first_day = month.replace(day=1)
    if month.month == 12:
        last_day = month.replace(year=month.year + 1, month=1, day=1) - timedelta(days=1)
    else:
        last_day = month.replace(month=month.month + 1, day=1) - timedelta(days=1)

    base_amount = func.coalesce(Transaction.amount_base, Transaction.amount)

    income_q = await db.execute(
        select(func.coalesce(func.sum(base_amount), 0))
        .where(Transaction.type == "income", Transaction.date >= first_day, Transaction.date <= last_day)
    )
    expense_q = await db.execute(
        select(func.coalesce(func.sum(base_amount), 0))
        .where(Transaction.type == "expense", Transaction.date >= first_day, Transaction.date <= last_day)
    )

    income = float(income_q.scalar())
    expenses = float(expense_q.scalar())
    savings = income - expenses

    return {
        "month": month.strftime("%Y-%m"),
        "income": income,
        "expenses": expenses,
        "savings": savings,
        "net": savings,
    }


async def get_category_breakdown(db: AsyncSession, date_from: date, date_to: date) -> list[dict]:
    base_amount = func.coalesce(Transaction.amount_base, Transaction.amount)

    result = await db.execute(
        select(
            Transaction.category_id,
            Category.name,
            Category.color,
            func.sum(base_amount).label("total"),
        )
        .join(Category, Transaction.category_id == Category.id, isouter=True)
        .where(
            Transaction.type == "expense",
            Transaction.date >= date_from,
            Transaction.date <= date_to,
        )
        .group_by(Transaction.category_id, Category.name, Category.color)
        .order_by(func.sum(base_amount).desc())
    )

    rows = result.all()
    grand_total = sum(float(r.total) for r in rows)

    return [
        {
            "category_id": str(r.category_id) if r.category_id else None,
            "category_name": r.name or "Uncategorized",
            "total": float(r.total),
            "percentage": round(float(r.total) / grand_total * 100, 1) if grand_total else 0,
            "color": r.color or "#95A5A6",
        }
        for r in rows
    ]


async def get_monthly_trend(db: AsyncSession, months: int = 12) -> list[dict]:
    n = int(months) - 1  # safe int, not user input
    result = await db.execute(text(f"""
        SELECT
            TO_CHAR(date_trunc('month', date), 'YYYY-MM') AS month,
            SUM(CASE WHEN type = 'income' THEN COALESCE(amount_base, amount) ELSE 0 END) AS income,
            SUM(CASE WHEN type = 'expense' THEN COALESCE(amount_base, amount) ELSE 0 END) AS expenses
        FROM transactions
        WHERE date >= date_trunc('month', CURRENT_DATE) - INTERVAL '{n} months'
        GROUP BY date_trunc('month', date)
        ORDER BY date_trunc('month', date)
    """))
    return [{"month": r.month, "income": float(r.income), "expenses": float(r.expenses)} for r in result]


async def get_historical_by_category(db: AsyncSession, months: int = 6) -> dict:
    n = int(months) - 1  # safe int, not user input
    result = await db.execute(text(f"""
        SELECT
            COALESCE(c.name, 'Uncategorized') AS category_name,
            TO_CHAR(date_trunc('month', t.date), 'YYYY-MM') AS month,
            SUM(COALESCE(t.amount_base, t.amount)) AS total
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.type = 'expense'
          AND t.date >= date_trunc('month', CURRENT_DATE) - INTERVAL '{n} months'
        GROUP BY c.name, date_trunc('month', t.date)
        ORDER BY c.name, date_trunc('month', t.date)
    """))

    data: dict[str, dict[str, float]] = {}
    for row in result:
        if row.category_name not in data:
            data[row.category_name] = {}
        data[row.category_name][row.month] = float(row.total)
    return data
