import asyncio
import logging

import httpx
from tenacity import (
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)

from app.config import settings

logger = logging.getLogger(__name__)

# Cap concurrent Gemini calls. The free tier rate-limits hard (429) once a few
# requests overlap — e.g. a statement import plus its categorization backlog.
# Serializing to 2 keeps throughput steady instead of triggering a 429 storm.
_gemini_semaphore = asyncio.Semaphore(2)

GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
FLASH = "gemini-2.5-flash"
# Tried in order — if the primary model is overloaded (503) the next one,
# which has separate capacity, is used as a fallback.
GENERATE_MODELS = ["gemini-2.5-flash", "gemini-2.0-flash"]

# HTTP statuses worth retrying — transient server-side / rate-limit errors.
_RETRYABLE_STATUS = {429, 500, 502, 503, 504}


def gemini_url(model: str, action: str) -> str:
    if not settings.gemini_api_key:
        raise RuntimeError(
            "GEMINI_API_KEY is not configured — set it in .env to use AI features "
            "(categorization, OCR, chat, forecast, statement import)."
        )
    return f"{GEMINI_BASE}/{model}:{action}?key={settings.gemini_api_key}"


def _is_transient(exc: BaseException) -> bool:
    """True for errors worth retrying — overload, rate limit, network blips."""
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code in _RETRYABLE_STATUS
    return isinstance(exc, (httpx.TimeoutException, httpx.TransportError))


@retry(
    retry=retry_if_exception(_is_transient),
    stop=stop_after_attempt(4),
    wait=wait_exponential(multiplier=2, min=4, max=30),
    reraise=True,
)
async def _post_gemini(url: str, body: dict) -> dict:
    """POST to Gemini with backoff retry on transient (429/5xx/network) errors."""
    async with _gemini_semaphore:
        async with httpx.AsyncClient(timeout=120) as client:
            r = await client.post(url, json=body)
            r.raise_for_status()
            return r.json()


async def generate(
    prompt: str | list,
    model: str = FLASH,
    max_tokens: int = 512,
    temperature: float = 0,
    *,
    response_mime_type: str | None = None,
) -> str:
    """Simple text (or multimodal) generation. Returns response text.
    Thinking is disabled for deterministic JSON/text extraction tasks.
    Pass response_mime_type="application/json" to force valid JSON output.
    """
    if isinstance(prompt, str):
        contents = [{"parts": [{"text": prompt}]}]
    else:
        contents = [{"parts": prompt}]

    # Try the requested model first, then the remaining fallbacks. Each model
    # gets its own retry-with-backoff inside _post_gemini; if it is still
    # overloaded after that, move on to the next model's separate capacity.
    models = [model] + [m for m in GENERATE_MODELS if m != model]
    last_exc: Exception | None = None

    for candidate in models:
        generation_config: dict = {
            "maxOutputTokens": max_tokens,
            "temperature": temperature,
        }
        # thinkingConfig is only valid on 2.5-series models.
        if candidate.startswith("gemini-2.5"):
            generation_config["thinkingConfig"] = {"thinkingBudget": 0}
        if response_mime_type:
            generation_config["responseMimeType"] = response_mime_type

        body = {"contents": contents, "generationConfig": generation_config}
        try:
            data = await _post_gemini(gemini_url(candidate, "generateContent"), body)
        except httpx.HTTPStatusError as exc:
            last_exc = exc
            if _is_transient(exc) and candidate != models[-1]:
                logger.warning(
                    "Gemini model %s failed (%s) — falling back",
                    candidate,
                    exc.response.status_code,
                )
                continue
            raise
        parts = data["candidates"][0].get("content", {}).get("parts", [])
        if not parts:
            return ""
        return parts[0].get("text", "")

    assert last_exc is not None
    raise last_exc


async def stream_generate(messages: list[dict], system: str, model: str = FLASH):
    """Streaming chat. Yields text chunks. messages = [{role, content}, ...]
    Thinking is enabled with a separate budget so maxOutputTokens is fully available for text.
    """
    contents = []
    for m in messages:
        role = "user" if m["role"] == "user" else "model"
        contents.append({"role": role, "parts": [{"text": m["content"]}]})

    body = {
        "system_instruction": {"parts": [{"text": system}]},
        "contents": contents,
        "generationConfig": {
            "maxOutputTokens": 2048,
            "temperature": 0.7,
            "thinkingConfig": {"thinkingBudget": 1024},
        },
    }
    async with httpx.AsyncClient(timeout=120) as client:
        async with client.stream(
            "POST", gemini_url(model, "streamGenerateContent") + "&alt=sse", json=body
        ) as r:
            r.raise_for_status()
            async for line in r.aiter_lines():
                if line.startswith("data: "):
                    import json
                    try:
                        chunk = json.loads(line[6:])
                        parts = chunk["candidates"][0].get("content", {}).get("parts", [])
                        if parts:
                            text = parts[0].get("text", "")
                            if text:
                                yield text
                    except Exception:
                        pass
