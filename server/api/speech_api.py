import io
import json
import logging
import os
import shutil
import tempfile
import zipfile
from pathlib import Path

import requests
import speech_recognition as sr
from fastapi import APIRouter, HTTPException, UploadFile
from pydantic import BaseModel, Field

from server.utils.responses import ok

logger = logging.getLogger("smartstudy.speech")

router = APIRouter(prefix="/speech", tags=["speech"])

# 长语音分段时长（毫秒）
CHUNK_DURATION_MS = 15000
# 静音阈值（dBFS）
SILENCE_THRESHOLD = -40

# Vosk 模型路径
VOSK_MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "vosk"
VOSK_MODEL_NAME = "vosk-model-small-cn-0.22"
VOSK_MODEL_ZIP = VOSK_MODEL_DIR / f"{VOSK_MODEL_NAME}.zip"
VOSK_MODEL_PATH = VOSK_MODEL_DIR / VOSK_MODEL_NAME
VOSK_MODEL_URL = f"https://alphacephei.com/vosk/models/{VOSK_MODEL_NAME}.zip"

_vosk_model = None


def _find_ffmpeg() -> str:
    """查找 ffmpeg 可执行文件路径"""
    # 1. 优先使用环境变量 FFMPEG_PATH
    env_path = os.environ.get("FFMPEG_PATH")
    if env_path and Path(env_path).exists():
        return env_path
    # 2. 尝试 ffmpeg-downloader 自动安装的路径（pip install 后自动下载）
    try:
        import ffmpeg_downloader
        ffmpeg_path = ffmpeg_downloader.ffmpeg_path
        if ffmpeg_path and Path(ffmpeg_path).exists():
            return ffmpeg_path
    except ImportError:
        pass
    # 3. 从系统 PATH 查找
    found = shutil.which("ffmpeg")
    if found:
        return found
    # 4. 最后 fallback，让系统自己找
    return "ffmpeg"


FFMPEG_PATH = _find_ffmpeg()


def _set_ffmpeg():
    """设置 pydub 的 ffmpeg 路径"""
    from pydub import AudioSegment
    AudioSegment.ffmpeg = FFMPEG_PATH


class RecognizeResult(BaseModel):
    text: str = Field(default="", description="识别出的文字")
    success: bool = Field(default=False, description="是否识别成功")


def _ensure_vosk_model() -> bool:
    """确保 Vosk 中文模型已下载，返回是否可用"""
    if VOSK_MODEL_PATH.exists():
        return True
    logger.info("Vosk 中文模型未找到，准备下载（约42MB）...")
    try:
        VOSK_MODEL_DIR.mkdir(parents=True, exist_ok=True)
        logger.info("正在从 %s 下载模型...", VOSK_MODEL_URL)
        r = requests.get(VOSK_MODEL_URL, stream=True, timeout=120)
        r.raise_for_status()
        total = 0
        with open(VOSK_MODEL_ZIP, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    total += len(chunk)
        logger.info("模型下载完成 (%d 字节)，正在解压...", total)
        with zipfile.ZipFile(VOSK_MODEL_ZIP, "r") as zf:
            zf.extractall(VOSK_MODEL_DIR)
        VOSK_MODEL_ZIP.unlink()
        logger.info("Vosk 中文模型解压完成")
        return True
    except Exception as e:
        logger.warning("Vosk 模型下载失败: %s", e)
        return False


def _load_vosk_model():
    """加载 Vosk 模型（全局单例）"""
    global _vosk_model
    if _vosk_model is not None:
        return _vosk_model
    if not VOSK_MODEL_PATH.exists():
        if not _ensure_vosk_model():
            return None
    try:
        import vosk
        _vosk_model = vosk.Model(str(VOSK_MODEL_PATH))
        logger.info("Vosk 模型加载成功")
        return _vosk_model
    except Exception as e:
        logger.warning("Vosk 模型加载失败: %s", e)
        return None


def _recognize_vosk(audio_data: sr.AudioData) -> str | None:
    """使用 Vosk 离线识别中文语音"""
    model = _load_vosk_model()
    if model is None:
        return None
    try:
        import vosk
        rec = vosk.KaldiRecognizer(model, audio_data.sample_rate)
        rec.AcceptWaveform(audio_data.get_raw_data())
        result = json.loads(rec.FinalResult())
        text = result.get("text", "").strip()
        return text if text else None
    except Exception as e:
        logger.warning("Vosk 识别失败: %s", e)
        return None


def _load_audio(wav_bytes: bytes):
    """加载音频为 AudioSegment，带降噪和归一化处理"""
    _set_ffmpeg()
    from pydub import AudioSegment
    from pydub.effects import normalize
    seg = AudioSegment.from_file(io.BytesIO(wav_bytes), format="wav")
    # 降噪：高通滤波去除低频噪声（< 80Hz）
    seg = seg.high_pass_filter(80)
    # 音量归一化到 -3dBFS
    seg = normalize(seg, headroom=3.0)
    # 整体增益 +10dB
    seg = seg.apply_gain(10.0)
    return seg


def _split_audio(seg) -> list:
    """将长音频按静音分割成多个片段"""
    _set_ffmpeg()
    from pydub.silence import split_on_silence
    chunks = split_on_silence(
        seg,
        min_silence_len=500,
        silence_thresh=SILENCE_THRESHOLD,
        keep_silence=300,
    )
    # 如果分段后没有有效片段，整体返回
    if not chunks:
        return [seg]
    # 将过短的片段合并到前一个片段
    merged = []
    buffer = chunks[0]
    for chunk in chunks[1:]:
        if len(buffer) < CHUNK_DURATION_MS or len(chunk) < 2000:
            buffer = buffer + chunk
        else:
            merged.append(buffer)
            buffer = chunk
    if len(buffer) > 0:
        merged.append(buffer)
    # 如果分段依然太长，按固定时长切割
    final_chunks = []
    for chunk in merged:
        if len(chunk) > CHUNK_DURATION_MS:
            for start_ms in range(0, len(chunk), CHUNK_DURATION_MS):
                final_chunks.append(chunk[start_ms:start_ms + CHUNK_DURATION_MS])
        else:
            final_chunks.append(chunk)
    return final_chunks


def _export_wav(seg) -> bytes:
    """将 AudioSegment 导出为 WAV 字节"""
    _set_ffmpeg()
    buf = io.BytesIO()
    seg.export(buf, format="wav")
    return buf.getvalue()


def _recognize_chunk(recognizer, wav_bytes: bytes, engine: str = "google") -> str | None:
    """识别单个音频片段"""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp.write(wav_bytes)
        tmp_path = tmp.name
    try:
        with sr.AudioFile(tmp_path) as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.3)
            recognizer.energy_threshold = 300
            audio = recognizer.record(source)

        if engine == "vosk":
            # Vosk 离线识别（中文，不依赖网络）
            return _recognize_vosk(audio)
        elif engine == "google":
            try:
                return recognizer.recognize_google(audio, language="zh-CN")
            except sr.UnknownValueError:
                return None
            except sr.RequestError as e:
                logger.warning("Google语音识别请求失败: %s", e)
                return None
        else:
            # Sphinx 离线识别（需中文语言模型）
            try:
                return recognizer.recognize_sphinx(audio, language="zh-CN")
            except Exception as e:
                logger.warning("Sphinx识别失败: %s", e)
                return None
    finally:
        Path(tmp_path).unlink(missing_ok=True)


@router.post("/recognize")
async def recognize_audio(file: UploadFile):
    try:
        raw = await file.read()
        if not raw:
            raise HTTPException(status_code=400, detail="音频文件为空")
        ext = Path(file.filename or "audio.wav").suffix.lower()
        supported = (".wav", ".mp3", ".m4a", ".ogg", ".aac", ".webm")
        if ext not in supported:
            logger.warning("不支持的音频格式: %s", ext)
            raise HTTPException(
                status_code=400,
                detail=f"不支持的音频格式: {ext}，请使用 {'/'.join(supported)}"
            )
        recognizer = sr.Recognizer()
        # 非 WAV 格式转为 WAV
        if ext != ".wav":
            try:
                _set_ffmpeg()
                from pydub import AudioSegment
            except ImportError:
                raise HTTPException(status_code=500, detail="服务端音频转换库 pydub 未安装")
            segment = AudioSegment.from_file(io.BytesIO(raw), format=ext.lstrip("."))
            wav_bytes = _export_wav(segment)
        else:
            wav_bytes = raw
        # 降噪 + 归一化 + 增益处理
        try:
            audio_seg = _load_audio(wav_bytes)
            wav_bytes = _export_wav(audio_seg)
        except Exception as e:
            logger.warning("音频预处理失败，使用原始音频: %s", e)
        # 将长音频分割为片段
        try:
            _set_ffmpeg()
            from pydub import AudioSegment
            seg = AudioSegment.from_file(io.BytesIO(wav_bytes), format="wav")
            chunks = _split_audio(seg)
        except Exception as e:
            logger.warning("音频分割失败，使用整体音频: %s", e)
            chunks = [wav_bytes]
        # 识别引擎优先级：Vosk（离线中文） > Google（在线） > Sphinx（离线）
        engines = ["vosk", "google", "sphinx"]
        all_text_parts = []
        for engine in engines:
            if all_text_parts:
                break
            for chunk in chunks:
                if isinstance(chunk, bytes):
                    chunk_wav = chunk
                else:
                    chunk_wav = _export_wav(chunk)
                text = _recognize_chunk(recognizer, chunk_wav, engine=engine)
                if text:
                    all_text_parts.append(text)
        if all_text_parts:
            full_text = "".join(all_text_parts)
            engine_name = "Vosk离线" if engines[0] == "vosk" else "在线"
            return ok(
                RecognizeResult(text=full_text, success=True).model_dump(),
                f"语音识别成功（{engine_name}模式）"
            )
        return ok(
            RecognizeResult(text="", success=False).model_dump(),
            "未能识别出语音内容，请靠近麦克风清晰说话后重试"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error("语音识别失败: %s", e)
        raise HTTPException(status_code=500, detail=f"语音识别处理失败: {e}")