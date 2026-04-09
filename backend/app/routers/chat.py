import uuid

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import Auth, DBSession
from app.models.chat import ChatMessage, ChatSession
from app.schemas.chat import ChatMessageCreate, ChatMessageOut, ChatSessionOut

router = APIRouter(dependencies=[Auth])


@router.get("/sessions", response_model=list[ChatSessionOut])
async def list_sessions(db: AsyncSession = DBSession):
    result = await db.execute(select(ChatSession).order_by(ChatSession.updated_at.desc()))
    return list(result.scalars().all())


@router.post("/sessions", response_model=ChatSessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(db: AsyncSession = DBSession):
    session = ChatSession()
    db.add(session)
    await db.flush()
    await db.refresh(session)
    return session


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(session_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(select(ChatSession).where(ChatSession.id == session_id))
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    await db.delete(session)
    await db.flush()


@router.get("/sessions/{session_id}/messages", response_model=list[ChatMessageOut])
async def get_messages(session_id: uuid.UUID, db: AsyncSession = DBSession):
    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at)
    )
    return list(result.scalars().all())


@router.post("/sessions/{session_id}/message")
async def send_message(
    session_id: uuid.UUID,
    data: ChatMessageCreate,
    db: AsyncSession = DBSession,
):
    result = await db.execute(
        select(ChatSession)
        .options(selectinload(ChatSession.messages))
        .where(ChatSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Save user message
    user_msg = ChatMessage(session_id=session_id, role="user", content=data.content)
    db.add(user_msg)
    await db.flush()

    from app.ai.assistant import stream_assistant_response
    return StreamingResponse(
        stream_assistant_response(db, session, data.content),
        media_type="text/event-stream",
    )
