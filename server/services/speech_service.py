import io
import json
import logging
import os
import shutil
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path

import requests
import speech_recognition as sr

logger = logging.getLogger("smartstudy.speech")

CHUNK_DURATION_MS = 15000
SILENCE_THRESHOLD = -40
SUPPORTED_EXTENSIONS = (".wav", ".mp3", ".m4a", ".ogg", ".aac", ".webm")

VOSK_MODEL_DIR = Path(__file__).resolve().parent.parent / "models" / "vosk"
VOSK_MODEL_NAME = "vosk-model-small-cn-0.22"
VOSK_MODEL_ZIP = VOSK_MODEL_DIR / f"{VOSK_MODEL_NAME}.zip"
VOSK_MODEL_PATH = VOSK_MODEL_DIR / VOSK_MODEL_NAME
VOSK_MODEL_URL = f"https://alphacephei.com/vosk/models/{VOSK_MODEL_NAME}.zip"

_vosk_model = None


class SpeechInputError(ValueError):
    pass


class SpeechDependencyError(RuntimeError):
    pass


@dataclass(frozen=True, slots=True)
class SpeechRecognitionOutcome:
    text: str
    success: bool
    message: str


def _find_ffmpeg() -> str:
    env_path = os.environ.get("FFMPEG_PATH")
    if env_path and Path(env_path).exists():
        return env_path
    try:
        import ffmpeg_downloader
        ffmpeg_path = ffmpeg_downloader.ffmpeg_path
        if ffmpeg_path and Path(ffmpeg_path).exists():
            return ffmpeg_path
    except ImportError:
        pass
    return shutil.which("ffmpeg") or "ffmpeg"


FFMPEG_PATH = _find_ffmpeg()


def _set_ffmpeg() -> None:
    from pydub import AudioSegment

    AudioSegment.ffmpeg = FFMPEG_PATH


def _ensure_vosk_model() -> bool:
    if VOSK_MODEL_PATH.exists():
        return True
    logger.info("Vosk 中文模型未找到，准备下载（约42MB）")
    try:
        VOSK_MODEL_DIR.mkdir(parents=True, exist_ok=True)
        with requests.get(VOSK_MODEL_URL, stream=True, timeout=120) as response:
            response.raise_for_status()
            with open(VOSK_MODEL_ZIP, "wb") as model_file:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        model_file.write(chunk)
        with zipfile.ZipFile(VOSK_MODEL_ZIP, "r") as archive:
            archive.extractall(VOSK_MODEL_DIR)
        VOSK_MODEL_ZIP.unlink(missing_ok=True)
        logger.info("Vosk 中文模型准备完成")
        return True
    except Exception as exc:
        logger.warning("Vosk 模型下载失败: %s", exc)
        return False


def _load_vosk_model():
    global _vosk_model
    if _vosk_model is not None:
        return _vosk_model
    if not VOSK_MODEL_PATH.exists() and not _ensure_vosk_model():
        return None
    try:
        import vosk

        _vosk_model = vosk.Model(str(VOSK_MODEL_PATH))
        return _vosk_model
    except Exception as exc:
        logger.warning("Vosk 模型加载失败: %s", exc)
        return None


def _recognize_vosk(audio_data: sr.AudioData) -> str | None:
    model = _load_vosk_model()
    if model is None:
        return None
    try:
        import vosk

        recognizer = vosk.KaldiRecognizer(model, audio_data.sample_rate)
        recognizer.AcceptWaveform(audio_data.get_raw_data())
        text = json.loads(recognizer.FinalResult()).get("text", "").strip()
        return text or None
    except Exception as exc:
        logger.warning("Vosk 识别失败: %s", exc)
        return None


def _load_audio(wav_bytes: bytes):
    _set_ffmpeg()
    from pydub import AudioSegment
    from pydub.effects import normalize

    segment = AudioSegment.from_file(io.BytesIO(wav_bytes), format="wav")
    segment = segment.high_pass_filter(80)
    segment = normalize(segment, headroom=3.0)
    return segment.apply_gain(10.0)


def _split_audio(segment) -> list:
    _set_ffmpeg()
    from pydub.silence import split_on_silence

    chunks = split_on_silence(
        segment,
        min_silence_len=500,
        silence_thresh=SILENCE_THRESHOLD,
        keep_silence=300,
    )
    if not chunks:
        return [segment]

    # 短片段合并可保留完整语义，最终长度上限则避免单次识别超时。
    merged = []
    buffer = chunks[0]
    for chunk in chunks[1:]:
        if len(buffer) < CHUNK_DURATION_MS or len(chunk) < 2000:
            buffer += chunk
        else:
            merged.append(buffer)
            buffer = chunk
    if len(buffer) > 0:
        merged.append(buffer)

    final_chunks = []
    for chunk in merged:
        if len(chunk) <= CHUNK_DURATION_MS:
            final_chunks.append(chunk)
            continue
        for start_ms in range(0, len(chunk), CHUNK_DURATION_MS):
            final_chunks.append(chunk[start_ms:start_ms + CHUNK_DURATION_MS])
    return final_chunks


def _export_wav(segment) -> bytes:
    _set_ffmpeg()
    buffer = io.BytesIO()
    segment.export(buffer, format="wav")
    return buffer.getvalue()


def _recognize_chunk(recognizer: sr.Recognizer, wav_bytes: bytes, engine: str) -> str | None:
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
        temp_file.write(wav_bytes)
        temp_path = temp_file.name
    try:
        with sr.AudioFile(temp_path) as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.3)
            recognizer.energy_threshold = 300
            audio = recognizer.record(source)

        if engine == "vosk":
            return _recognize_vosk(audio)
        if engine == "google":
            try:
                return recognizer.recognize_google(audio, language="zh-CN")
            except (sr.UnknownValueError, sr.RequestError) as exc:
                logger.info("Google 语音识别未返回结果: %s", exc)
                return None
        try:
            return recognizer.recognize_sphinx(audio, language="zh-CN")
        except Exception as exc:
            logger.info("Sphinx 语音识别未返回结果: %s", exc)
            return None
    finally:
        Path(temp_path).unlink(missing_ok=True)


def recognize_audio(raw: bytes, filename: str) -> SpeechRecognitionOutcome:
    if not raw:
        raise SpeechInputError("音频文件为空")
    extension = Path(filename).suffix.lower()
    if extension not in SUPPORTED_EXTENSIONS:
        raise SpeechInputError(
            f"不支持的音频格式: {extension}，请使用 {'/'.join(SUPPORTED_EXTENSIONS)}"
        )

    if extension != ".wav":
        try:
            _set_ffmpeg()
            from pydub import AudioSegment
        except ImportError as exc:
            raise SpeechDependencyError("服务端音频转换库 pydub 未安装") from exc
        segment = AudioSegment.from_file(io.BytesIO(raw), format=extension.lstrip("."))
        wav_bytes = _export_wav(segment)
    else:
        wav_bytes = raw

    try:
        wav_bytes = _export_wav(_load_audio(wav_bytes))
    except Exception as exc:
        logger.warning("音频预处理失败，使用原始音频: %s", exc)

    try:
        _set_ffmpeg()
        from pydub import AudioSegment

        chunks = _split_audio(AudioSegment.from_file(io.BytesIO(wav_bytes), format="wav"))
    except Exception as exc:
        logger.warning("音频分割失败，使用整体音频: %s", exc)
        chunks = [wav_bytes]

    # 优先使用本地中文模型；只有整段没有结果时才切换下一识别引擎。
    recognizer = sr.Recognizer()
    for engine in ("vosk", "google", "sphinx"):
        text_parts: list[str] = []
        for chunk in chunks:
            chunk_wav = chunk if isinstance(chunk, bytes) else _export_wav(chunk)
            text = _recognize_chunk(recognizer, chunk_wav, engine)
            if text:
                text_parts.append(text)
        if text_parts:
            engine_names = {"vosk": "Vosk 离线", "google": "Google 在线", "sphinx": "Sphinx 离线"}
            return SpeechRecognitionOutcome(
                text="".join(text_parts),
                success=True,
                message=f"语音识别成功（{engine_names[engine]}模式）",
            )

    return SpeechRecognitionOutcome(
        text="",
        success=False,
        message="未能识别出语音内容，请靠近麦克风清晰说话后重试",
    )
