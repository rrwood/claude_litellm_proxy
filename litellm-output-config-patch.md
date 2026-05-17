# LiteLLM Fix: `output_config` passed to non-Anthropic providers

## Problem

When using Claude Code with a LiteLLM proxy routing to non-Anthropic backends (e.g. Nvidia NIM,
Bedrock), requests fail with:

```
litellm.BadRequestError: Nvidia_nimException - Validation: Unsupported parameter(s):
`output_config`. Received Model Group=claude-sonnet-4-6
```

## Root Cause

Claude Code sends requests to LiteLLM's Anthropic-compatible `/v1/messages` endpoint. LiteLLM
handles this via an **experimental pass-through adapter** which translates Anthropic API format
to the target provider's format.

`output_config` leaks into `completion_kwargs` via **three separate code paths**, all of which
must be addressed:

**1. `adapters/transformation.py` — supported params list**

`output_config` is listed as a recognised Anthropic parameter. Unlike `output_format` (which has
a dedicated translation function), `output_config` has no translation logic and is forwarded raw.

**2. `adapters/handler.py` — explicit injection from extra_kwargs**

The handler actively re-injects `output_config` into `request_data` before translation:

```python
if "output_config" in extra_kwargs:
    request_data["output_config"] = extra_kwargs["output_config"]
```

**3. `messages/transformation.py` — injection into optional_params**

The messages transformer also sets `output_config` in `optional_params` (used for effort/thinking
level mapping), which flows into `completion_kwargs`:

```python
optional_params["output_config"] = existing_output_config
```

The `drop_params: true` setting (both global `litellm_settings` and per-model `litellm_params`)
does **not** intercept parameters at this layer and does not fix the problem.

## Affected Versions

- Confirmed on: **1.83.14**
- Likely affects all versions from ~1.80 onward where `output_config` was added
- GitHub issue: https://github.com/BerriAI/litellm/issues/22797 (filed for Bedrock; same root cause)

## Fix

> **Note:** Adjust `python3.12` to match your version. Run `pip show litellm` to confirm location.

### Patch 1 — Remove from supported params list (`adapters/transformation.py`)

```bash
sudo sed -i '/"output_config",/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/transformation.py
```

Verify — should return no output:
```bash
grep -n "output_config" \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/transformation.py
```

### Patch 2 — Remove extra_kwargs injection (`adapters/handler.py`)

```bash
sudo sed -i \
  '/if "output_config" in extra_kwargs:/,/request_data\["output_config"\] = extra_kwargs\["output_config"\]/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/handler.py
```

Verify — should return no output:
```bash
grep -n 'request_data\["output_config"\]' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/handler.py
```

### Patch 3 — Remove optional_params injection (`messages/transformation.py`)

```bash
# Remove from supported params list
sudo sed -i '/"output_config",/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/messages/transformation.py

# Remove the optional_params injection block
sudo sed -i \
  '/existing_output_config = optional_params.get("output_config")/,/optional_params\["output_config"\] = existing_output_config/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/messages/transformation.py
```

Verify — should return only a comment line, no assignment lines:
```bash
grep -n "output_config" \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/messages/transformation.py
```

### Patch 4 — Explicit pop before acompletion call (`adapters/handler.py`) ✅ confirmed fix

The definitive safety net — pop `output_config` immediately before the `acompletion` call so it
can never reach the provider regardless of how it got into `completion_kwargs`:

```bash
sudo sed -i \
  's/        completion_response = await litellm.acompletion(\*\*completion_kwargs)/        completion_kwargs.pop("output_config", None)\n        completion_response = await litellm.acompletion(**completion_kwargs)/' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/handler.py
```

Verify:
```bash
grep -n -A1 'completion_kwargs.pop' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/handler.py
```

Should show:
```python
        completion_kwargs.pop("output_config", None)
        completion_response = await litellm.acompletion(**completion_kwargs)
```

### Step 5 — Restart LiteLLM

```bash
sudo systemctl restart litellm
```

## Docker / Container Environments

Patches don't survive container restarts. Bake all four into your `Dockerfile`:

```dockerfile
FROM ghcr.io/berriai/litellm:main-latest

# Patch 1: remove output_config from adapters supported params list
RUN sed -i '/"output_config",/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/transformation.py

# Patch 2: remove extra_kwargs injection in adapters handler
RUN sed -i \
  '/if "output_config" in extra_kwargs:/,/request_data\["output_config"\] = extra_kwargs\["output_config"\]/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/handler.py

# Patch 3a: remove output_config from messages supported params list
RUN sed -i '/"output_config",/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/messages/transformation.py

# Patch 3b: remove optional_params injection in messages transformation
RUN sed -i \
  '/existing_output_config = optional_params.get("output_config")/,/optional_params\["output_config"\] = existing_output_config/d' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/messages/transformation.py

# Patch 4: explicit pop before acompletion call (definitive fix)
RUN sed -i \
  's/        completion_response = await litellm.acompletion(\*\*completion_kwargs)/        completion_kwargs.pop("output_config", None)\n        completion_response = await litellm.acompletion(**completion_kwargs)/' \
  /usr/lib/python3.12/site-packages/litellm/llms/anthropic/experimental_pass_through/adapters/handler.py
```

## LiteLLM Config (for reference)

Routing Claude model aliases to Nvidia NIM — `drop_params` alone is not sufficient:

```yaml
model_list:
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct
      api_key: os.environ/NVIDIA_NIM_API_KEY
      drop_params: true   # not sufficient on its own, patches above are required

litellm_settings:
  drop_params: true       # not sufficient on its own, patches above are required
```

## Applying Patches Automatically

A bash script `patch-litellm-output-config.sh` is available that applies all four patches
automatically. It is idempotent (safe to run multiple times) and auto-locates the LiteLLM install
path via Python rather than relying on hardcoded paths.

```bash
chmod +x patch-litellm-output-config.sh
./patch-litellm-output-config.sh
sudo systemctl restart litellm
```

For Docker, call it from your entrypoint before starting LiteLLM, or bake it in with `RUN`.

## Identifying Which Model Is Actually Responding

**Do not rely on asking the model** — many models (including Qwen3) are trained to deflect
identity questions or give a false answer. Qwen3 was observed claiming to be Claude Sonnet during
testing.

The reliable method is to check the LiteLLM proxy logs, which always show the actual routed model:

```bash
sudo journalctl -u litellm -f
# or for Docker:
docker logs -f <container_name>
```

Look for a line like:
```
LiteLLM completion() model= nvidia_nim/qwen/qwen3-coder-480b-a35b-instruct
```

## When to Remove This Fix

Before upgrading LiteLLM, check whether the upstream bug has been resolved. Look for a commit or
release note mentioning `output_config` being stripped in the pass-through adapter for
non-Anthropic providers. Once fixed upstream, remove the Dockerfile `RUN sed` lines to avoid
double-patching.
