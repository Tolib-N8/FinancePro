from datetime import date

from app.routers.accounts import _tx_signature
from app.services import statement_import_service as sis


# ---- _parse_amount -------------------------------------------------------

def test_parse_amount_plain():
    assert sis._parse_amount("123.45") == 123.45
    assert sis._parse_amount("1000") == 1000.0


def test_parse_amount_european_format():
    assert sis._parse_amount("1.234,56") == 1234.56
    assert sis._parse_amount("1 234,56") == 1234.56
    assert sis._parse_amount("1 234,56") == 1234.56  # non-breaking space


def test_parse_amount_negatives():
    assert sis._parse_amount("(123.45)") == -123.45
    assert sis._parse_amount("123.45-") == -123.45
    assert sis._parse_amount("−123.45") == -123.45  # unicode minus


def test_parse_amount_currency_symbols():
    assert sis._parse_amount("$1,234.56") == 1234.56
    assert sis._parse_amount("1 234,56 ₽") == 1234.56  # ruble sign


def test_parse_amount_invalid():
    assert sis._parse_amount("") is None
    assert sis._parse_amount(None) is None
    assert sis._parse_amount("abc") is None


# ---- _find_header --------------------------------------------------------

def test_find_header_english():
    fields = ["Date", "Description", "Amount", "Currency"]
    assert sis._find_header(fields, "date") == "Date"
    assert sis._find_header(fields, "description") == "Description"
    assert sis._find_header(fields, "amount") == "Amount"
    assert sis._find_header(fields, "currency") == "Currency"


def test_find_header_russian():
    fields = ["Дата операции", "Назначение", "Сумма", "Валюта"]
    assert sis._find_header(fields, "date") == "Дата операции"
    assert sis._find_header(fields, "description") == "Назначение"
    assert sis._find_header(fields, "amount") == "Сумма"


# ---- _parse_date ---------------------------------------------------------

def test_parse_date_iso_format_not_misread_as_dayfirst():
    # Regression: dateutil with dayfirst=True flips "2026-05-01" to "2026-01-05".
    # The ISO branch must keep year-first ordering.
    assert sis._parse_date("2026-05-01") == date(2026, 5, 1)
    assert sis._parse_date("2024-03-07") == date(2024, 3, 7)
    assert sis._parse_date("2024/03/07") == date(2024, 3, 7)
    assert sis._parse_date("2024.03.07") == date(2024, 3, 7)


def test_parse_date_european_dayfirst_preserved():
    assert sis._parse_date("01/05/2026") == date(2026, 5, 1)
    assert sis._parse_date("15.01.2024") == date(2024, 1, 15)
    assert sis._parse_date("01-05-2026") == date(2026, 5, 1)


def test_parse_date_invalid_returns_none():
    assert sis._parse_date("") is None
    assert sis._parse_date(None) is None
    assert sis._parse_date("not a date") is None


# ---- _resolve_amount -----------------------------------------------------

def test_resolve_amount_signed_single_column():
    assert sis._resolve_amount({"amount": "-50"}, "amount", None, None) == (50.0, "expense")
    assert sis._resolve_amount({"amount": "50"}, "amount", None, None) == (50.0, "income")
    assert sis._resolve_amount({"amount": "0"}, "amount", None, None) is None


def test_resolve_amount_debit_credit_columns():
    assert sis._resolve_amount({"debit": "30", "credit": ""}, None, "debit", "credit") == (30.0, "expense")
    assert sis._resolve_amount({"debit": "", "credit": "70"}, None, "debit", "credit") == (70.0, "income")


# ---- _parse_tabular_statement (async, pure CSV path) ---------------------

async def test_parse_tabular_statement_comma_signed():
    csv_text = (
        "Date,Description,Amount,Currency\n"
        "2024-01-15,Coffee Shop,-4.50,USD\n"
        "2024-01-16,Salary,2000,USD\n"
    )
    entries = await sis._parse_tabular_statement(csv_text.encode("utf-8"), "USD")
    assert len(entries) == 2
    assert entries[0].date == date(2024, 1, 15)
    assert entries[0].amount == 4.5
    assert entries[0].tx_type == "expense"
    assert entries[0].description == "Coffee Shop"
    assert entries[1].tx_type == "income"
    assert entries[1].amount == 2000.0


async def test_parse_tabular_statement_semicolon_russian_debit_credit():
    csv_text = (
        "Дата;Назначение;Списание;Поступление;Валюта\n"
        "15.01.2024;Магазин;1 234,56;;RUB\n"
        "16.01.2024;Зарплата;;50 000,00;RUB\n"
    )
    entries = await sis._parse_tabular_statement(csv_text.encode("utf-8"), "RUB")
    assert len(entries) == 2
    assert entries[0].tx_type == "expense"
    assert entries[0].amount == 1234.56
    assert entries[0].currency == "RUB"
    assert entries[1].tx_type == "income"
    assert entries[1].amount == 50000.0


# ---- _parse_json (LLM response cleanup) ----------------------------------

def test_parse_json_plain_object():
    assert sis._parse_json('{"transactions": []}') == {"transactions": []}


def test_parse_json_strips_markdown_fence():
    text = '```json\n{"transactions": [{"amount": 1}]}\n```'
    assert sis._parse_json(text) == {"transactions": [{"amount": 1}]}


def test_parse_json_tolerates_trailing_extra_data():
    # Regression: Gemini sometimes appends chatter after the JSON object,
    # which made bare json.loads raise "Extra data". raw_decode must accept it.
    text = '{"transactions": [{"amount": 1}]}\n\nNotes: this is unstructured trailing text.'
    assert sis._parse_json(text) == {"transactions": [{"amount": 1}]}


def test_parse_json_accepts_bare_array():
    # If Gemini returns just the array (forgetting the wrapper object),
    # the parser should still recover by treating it as the transactions list.
    text = '[{"amount": 1}, {"amount": 2}]'
    assert sis._parse_json(text) == {"transactions": [{"amount": 1}, {"amount": 2}]}


def test_parse_json_no_json_raises():
    import json as _json
    try:
        sis._parse_json("just some prose with no braces")
    except _json.JSONDecodeError:
        pass
    else:
        raise AssertionError("expected JSONDecodeError")


# ---- _tx_signature (router dedup key) ------------------------------------

def test_tx_signature_normalizes_case_whitespace_amount():
    d = date(2024, 1, 15)
    s1 = _tx_signature(d, "expense", 4.5, "usd", "  Coffee   Shop ")
    s2 = _tx_signature(d, "expense", 4.50, "USD", "coffee shop")
    assert s1 == s2


def test_tx_signature_distinguishes_type():
    d = date(2024, 1, 15)
    assert _tx_signature(d, "expense", 4.5, "USD", "Coffee") != _tx_signature(
        d, "income", 4.5, "USD", "Coffee"
    )
