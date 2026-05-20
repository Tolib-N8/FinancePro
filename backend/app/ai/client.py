import httpx

from app.config import settings

GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
FLASH = "gemini-2.5-flash"


def gemini_url(model: str, action: str) -> str:
    if not settings.gemini_api_key:
        raise RuntimeError(
            "GEMINI_API_KEY is not configured — set it in .env to use AI features "
            "(categorization, OCR, chat, forecast, statement import)."
        )
    return f"{GEMINI_BASE}/{model}:{action}?key={settings.gemini_api_key}"


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

    generation_config: dict = {
        "maxOutputTokens": max_tokens,
        "temperature": temperature,
        "thinkingConfig": {"thinkingBudget": 0},
    }
    if response_mime_type:
        generation_config["responseMimeType"] = response_mime_type

    body = {
        "contents": contents,
        "generationConfig": generation_config,
    }
    async with httpx.AsyncClient(timeout=120) as client:
        r = await client.post(gemini_url(model, "generateContent"), json=body)
        r.raise_for_status()
        data = r.json()
        parts = data["candidates"][0].get("content", {}).get("parts", [])
        if not parts:
            return ""
        return parts[0].get("text", "")


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
