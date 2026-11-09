"""Private JSON-lines worker owned by Life OS. No network or database access."""
import argparse
import contextlib
import json
import sys
from pathlib import Path

MAX_INPUT = 131072
MAX_PROMPT = 4096
MAX_REPLY = 384
REQUIRED_FILES = ("openvino_model.xml", "openvino_model.bin", "openvino_tokenizer.xml", "openvino_tokenizer.bin", "openvino_detokenizer.xml", "openvino_detokenizer.bin")


class RequestError(Exception):
    def __init__(self, code):
        self.code = code


def emit(value, output):
    output.write(json.dumps(value, ensure_ascii=False) + "\n")
    output.flush()


def validate_request(value):
    if not isinstance(value, dict) or type(value.get("id")) is not int:
        raise RequestError("invalid_request")
    messages = value.get("messages")
    start = value.get("turn_start")
    if not isinstance(messages, list) or not 2 <= len(messages) <= 32:
        raise RequestError("invalid_request")
    if type(start) is not int or not 1 <= start < len(messages):
        raise RequestError("invalid_request")
    for message in messages:
        if not isinstance(message, dict) or message.get("role") not in ("system", "user", "assistant", "tool"):
            raise RequestError("invalid_request")
        if not isinstance(message.get("content"), str) or len(message["content"]) > 32000:
            raise RequestError("invalid_request")
    if messages[0]["role"] != "system" or any(m["role"] == "system" for m in messages[1:]):
        raise RequestError("invalid_request")
    return [dict(m) for m in messages], start


def fit_prompt(tokenizer, messages, turn_start, max_prompt=MAX_PROMPT, tools=None):
    # Drop old turns only. Never trim instructions, the current request or its results.
    while True:
        prompt = tokenizer.apply_chat_template(messages, add_generation_prompt=True, tools=tools)
        length = tokenizer.encode(prompt, add_special_tokens=False).input_ids.shape[-1]
        if length <= max_prompt:
            return prompt
        if turn_start <= 1:
            raise RequestError("context_too_long")
        del messages[1]
        turn_start -= 1


def serve(pipeline, input_stream, output):
    tokenizer = pipeline.get_tokenizer()
    while True:
        line = input_stream.readline(MAX_INPUT + 1)
        if not line:
            return
        if len(line) > MAX_INPUT:
            emit({"code": "invalid_request"}, output)
            return
        request_id = None
        try:
            value = json.loads(line)
            if isinstance(value, dict):
                request_id = value.get("id")
            messages, start = validate_request(value)
            tools = value.get("tools")
            if tools is not None and (not isinstance(tools, list) or len(tools) > 8):
                raise RequestError("invalid_request")
            with contextlib.redirect_stdout(sys.stderr):
                prompt = fit_prompt(tokenizer, messages, start, tools=tools)
                answer = pipeline.generate(prompt, max_new_tokens=MAX_REPLY, do_sample=False, apply_chat_template=False)
            text = answer if isinstance(answer, str) else answer.texts[0]
            if not isinstance(text, str) or not text.strip() or len(text) > 32000:
                raise RequestError("generation_failed")
            emit({"id": request_id, "text": text}, output)
        except RequestError as error:
            emit({"id": request_id, "code": error.code}, output)
        except (ValueError, TypeError, KeyError):
            emit({"id": request_id, "code": "invalid_request"}, output)
        except Exception:
            emit({"id": request_id, "code": "generation_failed"}, output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--device", choices=("NPU", "GPU", "CPU"), default="NPU")
    args = parser.parse_args()
    output = sys.stdout
    if any(not (args.model / name).is_file() for name in REQUIRED_FILES):
        emit({"type": "startup_error", "code": "model_missing"}, output)
        return 1
    try:
        import openvino as ov
        import openvino_genai as genai
    except ImportError:
        emit({"type": "startup_error", "code": "missing_dependencies"}, output)
        return 1
    try:
        available = ov.Core().available_devices
        if not any(d.split(".")[0] == args.device for d in available):
            emit({"type": "startup_error", "code": "device_unavailable"}, output)
            return 1
        config = {"CACHE_DIR": str(args.model / ".openvino-cache")}
        if args.device == "NPU":
            config.update(MAX_PROMPT_LEN=MAX_PROMPT, MIN_RESPONSE_LEN=512)
        with contextlib.redirect_stdout(sys.stderr):
            pipeline = genai.LLMPipeline(str(args.model.resolve()), args.device, **config)
        emit({"type": "ready", "device": args.device, "model": args.model.name}, output)
        serve(pipeline, sys.stdin, output)
        return 0
    except Exception:
        emit({"type": "startup_error", "code": "load_failed"}, output)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
