#!/usr/bin/env python3
"""Patch LiteLLM's Anthropic streaming adapter so streamed replies stay valid
and complete when a model sends thinking and text in the same chunk.

Bugs (seen in LiteLLM 1.89.7), in
llms/anthropic/experimental_pass_through/adapters/streaming_iterator.py:

1. When a reply switches block type (thinking -> text), the chunk that starts
   the new block is dropped unless it holds tool arguments. The first words of
   the text or thinking are lost.

2. Some models (e.g. NVIDIA Nemotron) send one chunk that holds both the last
   thinking words and the first text words. LiteLLM opens a *text* block for it
   but turns it into a *thinking* delta. A thinking delta inside a text block
   breaks the Anthropic stream format, and Claude Code fails with
   "API Error: response stream was malformed".

The fix:
- a mixed chunk inside a text block becomes a text delta (first words kept);
- its thinking words go into the previous thinking block before it closes;
- the chunk that starts a new block is kept whenever it has content.

Idempotent and safe to re-run. Prints a warning (does not fail) if the code
has changed, e.g. after a LiteLLM upgrade.

Usage: python3 patch-litellm-streaming.py
"""
import importlib.util
import pathlib
import re
import sys

MARKER = "# patched: mixed thinking/text chunks v2"

# 1. Keep the trigger chunk of a new block whenever it has content.
TRIGGER_OLD = re.compile(
    r'processed_chunk\["delta"\]\.get\("type"\)\s*==\s*"input_json_delta"\s*'
    r'and processed_chunk\["delta"\]\.get\("partial_json"\)'
)
TRIGGER_NEW = (
    '(processed_chunk["delta"].get("partial_json") '
    'or processed_chunk["delta"].get("text") '
    'or processed_chunk["delta"].get("thinking"))'
)

# 2. Fix mixed chunks right after translation (sync and async loops).
FIX_ANCHOR = re.compile(
    r"^(\s*)# Check if this is a usage chunk and we have a held stop_reason chunk",
    re.M,
)
FIX_INSERT = (
    r"\1processed_chunk, _mixed_leftover = self._fix_mixed_delta(chunk, processed_chunk)  "
    + MARKER
    + "\n"
    + r"\g<0>"
)

# 3. Before closing the old block, send it the leftover thinking words.
STOP_ANCHOR = re.compile(r"^(\s*)# 1\. Stop current content block", re.M)
STOP_INSERT = (
    r"\1if _mixed_leftover:" "\n"
    r"\1    self.chunk_queue.append({"
    r'"type": "content_block_delta", '
    r'"index": max(self.current_content_block_index - 1, 0), '
    r'"delta": {"type": "thinking_delta", "thinking": _mixed_leftover}})' "\n"
    r"\g<0>"
)

# 4. Helper method on the stream wrapper class.
METHOD_ANCHOR = re.compile(r"^    def _increment_content_block_index\(self\):", re.M)
METHOD = '''    def _fix_mixed_delta(self, chunk, processed_chunk):
        """Split a chunk holding both thinking and text. Returns
        (processed_chunk, leftover_thinking_for_previous_block)."""
        try:
            if processed_chunk.get("type") != "content_block_delta":
                return processed_chunk, None
            delta = processed_chunk.get("delta") or {}
            prev = getattr(self, "_last_delta_type", None)
            if (
                delta.get("type") == "thinking_delta"
                and self.current_content_block_type == "text"
            ):
                text = chunk.choices[0].delta.content or ""
                leftover = delta.get("thinking") if prev == "thinking_delta" else None
                processed_chunk = dict(processed_chunk)
                processed_chunk["delta"] = {"type": "text_delta", "text": text}
                self._last_delta_type = "text_delta"
                return processed_chunk, leftover
            self._last_delta_type = delta.get("type")
        except Exception:
            pass
        return processed_chunk, None

'''


def main():
    spec = importlib.util.find_spec("litellm")
    if spec is None or not spec.origin:
        sys.exit("litellm is not installed")
    path = (
        pathlib.Path(spec.origin).parent
        / "llms/anthropic/experimental_pass_through/adapters/streaming_iterator.py"
    )
    src = path.read_text()

    if MARKER in src:
        print(f"already patched: {path}")
        return

    counts = {}
    src, counts["trigger"] = TRIGGER_OLD.subn(TRIGGER_NEW, src)
    src, counts["fix"] = FIX_ANCHOR.subn(FIX_INSERT, src)
    src, counts["stop"] = STOP_ANCHOR.subn(STOP_INSERT, src)
    src, counts["method"] = METHOD_ANCHOR.subn(METHOD + r"\g<0>", src, count=1)

    expected = {"trigger": 2, "fix": 2, "stop": 2, "method": 1}
    if counts != expected:
        print(
            f"WARNING: code did not match (LiteLLM may have changed), not patched. "
            f"matches={counts} expected={expected}: {path}"
        )
        return

    compile(src, str(path), "exec")
    path.write_text(src)
    print(f"patched: {path}")


if __name__ == "__main__":
    main()
