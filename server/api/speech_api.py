import logging

from fastapi import APIRouter, HTTPException, UploadFile
from pydantic import BaseModel, Field
from starlette.concurrency import run_in_threadpool

from server.services.speech_service import SpeechDependencyError, SpeechInputError, recognize_audio
from server.utils.responses import ok

logger = logging.getLogger("smartstudy.speech.api")
router = APIRouter(prefix="/speech", tags=["speech"])


class RecognizeResult(BaseModel):
    text: str = Field(default="", description="识别出的文字")
    success: bool = Field(default=False, description="是否识别成功")


@router.post("/recognize")
async def recognize_audio_file(file: UploadFile):
    raw = await file.read()
    try:
        # 转码、切片和识别属于阻塞操作，放入线程池避免占用 FastAPI 事件循环。
        outcome = await run_in_threadpool(recognize_audio, raw, file.filename or "audio.wav")
    except SpeechInputError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except SpeechDependencyError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("语音识别处理失败")
        raise HTTPException(status_code=500, detail=f"语音识别处理失败: {exc}") from exc

    return ok(
        RecognizeResult(text=outcome.text, success=outcome.success).model_dump(),
        outcome.message,
    )
