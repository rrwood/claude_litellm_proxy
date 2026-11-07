# LiteLLM Fix: broken streamed replies in Anthropic format

## Problem

Claude Code clients using the proxy saw two kinds of failure on streamed replies:

- **Missing first words.** Replies started mid-word (e.g. "ivers are…" instead of "Rivers are…"), or were empty.
- **`API Error: response stream was malformed`.** Claude Code stopped the request and showed this error. It was seen mostly with Sonnet 5, which uses NVIDIA Nemotron (`nemotron-3.5-super-vl-120b`). In testing, about 1 in 6 replies failed.

Non-streamed requests (plain `curl` without `"stream": true`) do not show either problem.

## Root Cause

Claude Code talks the Anthropic Messages format. LiteLLM gets an OpenAI-style stream from the model and converts it into Anthropic stream events. Those events must follow strict rules: each content block (thinking, text or tool call) is opened with `content_block_start`, filled with deltas of the **matching type**, then closed with `content_block_stop`.

The conversion lives in
`litellm/llms/anthropic/experimental_pass_through/adapters/streaming_iterator.py`
and has two bugs.

### Bug 1 — first chunk of each block is dropped

When the reply switches block type (for example thinking → text), the chunk that causes the switch opens the new block. LiteLLM then throws that chunk away unless it holds tool arguments. For thinking and text, the first words are lost.

### Bug 2 — thinking delta inside a text block

Nemotron sometimes sends one chunk that holds **both** the last thinking words and the first text words. LiteLLM decides two things about that chunk in two different places:

| Decision | Rule | Result for a mixed chunk |
|---|---|---|
| Block type | text wins over thinking | opens a **text** block |
| Delta type | thinking wins over text | sends a **thinking** delta |

So a thinking delta is sent inside a text block. Claude Code rejects this as a malformed stream. Example captured from the live proxy:

```
event: content_block_start
data: {"type": "content_block_start", "index": 2, "content_block": {"type": "text", "text": ""}}

event: content_block_delta
data: {"type": "content_block_delta", "index": 2, "delta": {"type": "thinking_delta", "thinking": " output."}}

event: content_block_delta
data: {"type": "content_block_delta", "index": 2, "delta": {"type": "text_delta", "text": "ivers are the earth"}}
```

The first text letter ("R") from the same chunk is lost too.

Unpatched LiteLLM hides bug 2, because bug 1 throws the mixed chunk away (the stream stays valid but loses words). The first version of our patch fixed bug 1 only, which exposed bug 2. Version 2 of the patch (v1.0.1) fixes both.

## Affected Versions

Seen in LiteLLM **1.89.7** (the version the Dockerfile installs with `litellm>=1.60,<1.90`). Other versions may differ.

## Fix

`scripts/patch-litellm-streaming.py` edits `streaming_iterator.py` in place. It changes both the sync and the async stream loops:

1. **Keep the first chunk of a new block** whenever it has content (text, thinking or tool arguments), not only for tool arguments.
2. **Split mixed chunks.** A new helper, `_fix_mixed_delta`, runs on every converted chunk. If a thinking delta lands in a text block, it:
   - replaces it with a text delta holding the chunk's text, so the first words are kept;
   - returns the thinking words as "leftover".
3. **Send the leftover thinking to the right block.** Just before the old thinking block is closed, the leftover words are sent as a thinking delta to that block. They are only sent if the old block really was a thinking block. Otherwise they are dropped.

The script is safe to re-run (it checks for a marker comment). If LiteLLM's code has changed, it prints a warning and makes no changes, instead of failing the build.

## How It Is Applied

The patch runs during the Docker build, right after LiteLLM is installed:

```dockerfile
COPY scripts/patch-litellm-streaming.py /tmp/
RUN python3 /tmp/patch-litellm-streaming.py && rm /tmp/patch-litellm-streaming.py
```

Because it is part of the image, changes to the patch need a **rebuild** of the image. Restarting the container is not enough. In Portainer, use "Pull and redeploy" with re-pull/rebuild turned on.

Check the build log for one of these lines:

- `patched: …/streaming_iterator.py` — patch applied
- `already patched: …` — patch was already there
- `WARNING: code did not match …` — LiteLLM changed; the patch was **not** applied (see below)

## How to Check

Send a streamed request and look at the events:

```bash
curl -s -N http://PROXY_IP:4000/v1/messages \
  -H "x-api-key: DUMMY_KEY" -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-5","max_tokens":2000,"stream":true,
       "messages":[{"role":"user","content":"Write a short paragraph about rivers."}]}'
```

A good stream has:

- only `thinking_delta` events inside thinking blocks, and only `text_delta` events inside text blocks;
- a reply whose first word is complete (e.g. "Rivers", not "ivers");
- a final `message_stop` event.

Run it several times: the mixed chunk does not happen on every reply. A real Claude Code session (`claude -p "…"` pointed at the proxy) is also a good test.

## When to Remove This Fix

Before upgrading LiteLLM, check whether these bugs are fixed upstream. Look for changes to `streaming_iterator.py` around how the first chunk of a new content block is handled, and how chunks with both reasoning and text are converted. If the build log shows the `WARNING: code did not match` line after an upgrade, test streaming as above. If streams are valid and complete, remove the two patch lines from the Dockerfile and this script.

## Related Documents

- [README.md — LiteLLM Streaming Patch](../README.md#litellm-streaming-patch)
- [litellm-output-config-patch.md](litellm-output-config-patch.md) — the other LiteLLM patch used by this proxy
