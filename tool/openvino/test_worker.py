import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location("life_os_worker", Path(__file__).with_name("worker.py"))
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class Tokenizer:
    def apply_chat_template(self, messages, add_generation_prompt, tools=None):
        return "|".join(m["content"] for m in messages)

    def encode(self, prompt, add_special_tokens):
        return SimpleNamespace(input_ids=SimpleNamespace(shape=(1, len(prompt))))


class Pipeline:
    def __init__(self):
        self.calls = []

    def get_tokenizer(self):
        return Tokenizer()

    def generate(self, prompt, **kwargs):
        self.calls.append((prompt, kwargs))
        return '{"type":"message","text":"Привет"}'


class WorkerTest(unittest.TestCase):
    def request(self):
        return {"id": 1, "turn_start": 1, "messages": [{"role": "system", "content": "sys"}, {"role": "user", "content": "Привет"}]}

    def test_validates_schema_and_roles(self):
        for update in ({"id": True}, {"turn_start": 0}, {"messages": []}, {"messages": [{"role": "system", "content": "a"}, {"role": "system", "content": "b"}]}):
            with self.assertRaises(worker.RequestError):
                worker.validate_request(self.request() | update)

    def test_keeps_current_turn_while_dropping_old_history(self):
        messages = [{"role": "system", "content": "sys"}, {"role": "user", "content": "very old message"}, {"role": "assistant", "content": "old answer"}, {"role": "user", "content": "new"}]
        prompt = worker.fit_prompt(Tokenizer(), messages, 3, max_prompt=10)
        self.assertEqual(prompt, "sys|new")

    def test_never_truncates_current_request_or_tool_result(self):
        messages = [{"role": "system", "content": "sys"}, {"role": "user", "content": "a long current request"}]
        with self.assertRaises(worker.RequestError) as error:
            worker.fit_prompt(Tokenizer(), messages, 1, max_prompt=10)
        self.assertEqual(error.exception.code, "context_too_long")
        self.assertEqual(messages[-1]["content"], "a long current request")

    def test_stdio_preserves_unicode_and_recovers_after_invalid_json(self):
        pipeline = Pipeline()
        request = json.dumps(self.request(), ensure_ascii=False)
        output = io.StringIO()
        worker.serve(pipeline, io.StringIO(request + "\ninvalid\n" + request + "\n"), output)
        replies = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertIn("Привет", replies[0]["text"])
        self.assertEqual(replies[1]["code"], "invalid_request")
        self.assertEqual(len(pipeline.calls), 2)
        self.assertFalse(pipeline.calls[0][1]["apply_chat_template"])
        self.assertFalse(pipeline.calls[0][1]["do_sample"])

    def test_rejects_oversize_lines_without_processing_suffix(self):
        pipeline = Pipeline()
        output = io.StringIO()
        worker.serve(pipeline, io.StringIO("x" * (worker.MAX_INPUT + 1) + "\n"), output)
        self.assertEqual(json.loads(output.getvalue())["code"], "invalid_request")
        self.assertEqual(pipeline.calls, [])

    def test_reports_missing_model_without_importing_inference(self):
        with tempfile.TemporaryDirectory() as folder:
            result = subprocess.run([sys.executable, str(Path(worker.__file__)), "--model", folder], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["code"], "model_missing")
        self.assertNotIn("Traceback", result.stdout)


if __name__ == "__main__":
    unittest.main()
