import pytest

from server.services.speech_service import (
    SUPPORTED_EXTENSIONS,
    SpeechInputError,
    SpeechRecognitionOutcome,
    recognize_audio,
)


def test_speech_service_rejects_empty_audio_before_loading_engines():
    with pytest.raises(SpeechInputError, match="音频文件为空"):
        recognize_audio(b"", "audio.wav")


def test_speech_service_rejects_unsupported_extension():
    with pytest.raises(SpeechInputError, match="不支持的音频格式"):
        recognize_audio(b"not-audio", "audio.txt")


def test_speech_service_contract_is_explicit():
    outcome = SpeechRecognitionOutcome(text="测试", success=True, message="识别成功")

    assert outcome.text == "测试"
    assert outcome.success is True
    assert ".wav" in SUPPORTED_EXTENSIONS
