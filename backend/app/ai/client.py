import httpx

from app.config import settings

GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
FLASH = "gemini-1.5-flash"


def gemini_url(model: str, action: str) -> str:
    return f"{GEMINI_BASE}/{model}:{action}?key={settings.gemini_api_key}"


async def generate(prompt: str | list, model: str = FLASH, max_tokens: int = 512, temperature: float = 0) -> str:
    """Simple text (or multimodal) generation. Returns response text."""
    if isinstance(prompt, str):
        contents = [{"parts": [{"text": prompt}]}]
    else:
        contents = [{"parts": prompt}]

    body = {
        "contents": contents,
        "generationConfig": {"maxOutputTokens": max_tokens, "temperature": temperature},
    }
    async with httpx.AsyncClient(timeout=60) as client:
        r = await client.post(gemini_url(model, "generateContent"), json=body)
        r.raise_for_status()
        data = r.json()
        return data["candidates"][0]["content"]["parts"][0]["text"]


async def stream_generate(messages: list[dict], system: str, model: str = FLASH):
    """Streaming chat. Yields text chunks. messages = [{role, content}, ...]"""
    # Convert to Gemini format (user/model alternating)
    contents = []
    for m in messages:
        role = "user" if m["role"] == "user" else "model"
        contents.append({"role": role, "parts": [{"text": m["content"]}]})

    body = {
        "system_instruction": {"parts": [{"text": system}]},
        "contents": contents,
        "generationConfig": {"maxOutputTokens": 1024, "temperature": 0.7},
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
                        text = chunk["candidates"][0]["content"]["parts"][0].get("text", "")
                        if text:
                            yield text
                    except Exception:
                        pass
