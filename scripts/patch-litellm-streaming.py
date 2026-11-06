#!/usr/bin/env python3
"""Patch LiteLLM's Anthropic streaming adapter so the first text/thinking chunk
of each content block is not dropped.

Bug (seen in LiteLLM 1.89.7): when a streamed reply switches block type
(text -> thinking -> text), the chunk that triggers the new block is only kept
if it carries tool arguments (input_json_delta). Text and thinking trigger
chunks are discarded, but content_block_start is always empty, so their content
is lost. Claude Code then shows replies with the first words missing, or empty.

The fix keeps the trigger chunk whenever its delta has any content.

Idempotent and safe to re-run. Prints a warning (does not fail) if the code
has changed, e.g. after a LiteLLM upgrade that fixes the bug.

Usage: python3 patch-litellm-streaming.py
"""
import importlib.util
import pathlib
import re
import sys

MARKER = "# patched: keep text/thinking trigger chunk"

OLD = re.compile(
    r'processed_chunk\["delta"\]\.get\("type"\)\s*==\s*"input_json_delta"\s*'
    r'and processed_chunk\["delta"\]\.get\("partial_json"\)'
)
NEW = (
    '(processed_chunk["delta"].get("partial_json") '
    'or processed_chunk["delta"].get("text") '
    'or processed_chunk["delta"].get("thinking"))  ' + MARKER
)

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
    sys.exit(0)

new_src, count = OLD.subn(NEW, src)
if count == 0:
    print(f"WARNING: pattern not found, not patched (LiteLLM may have changed): {path}")
    sys.exit(0)

path.write_text(new_src)
print(f"patched {count} location(s): {path}")
