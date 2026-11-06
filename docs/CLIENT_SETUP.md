# Client Setup Guide

Configure Claude Code CLI to use the LiteLLM proxy for free NVIDIA NIM model access.

## Prerequisites

- Claude Code CLI installed ([Download](https://claude.ai/download))
- LiteLLM proxy running (see [README.md](../README.md))
- Proxy IP address (ask your admin, e.g. `192.168.111.50`)

## Setup

### Option 1: Claude Code Settings File (Recommended)

1. Copy `claude-settings.example.json` from this repo
2. Replace `PROXY_IP` with the actual proxy IP address
3. Save as `settings.json` in your Claude Code config directory:

| Platform | Path |
|----------|------|
| Windows  | `%USERPROFILE%\.claude\settings.json` |
| Mac      | `~/.claude/settings.json` |
| Linux    | `~/.claude/settings.json` |

Example for Windows:
```powershell
copy claude-settings.example.json %USERPROFILE%\.claude\settings.json
# Then edit the file and replace PROXY_IP with the actual IP
```

Example for Mac/Linux:
```bash
cp claude-settings.example.json ~/.claude/settings.json
# Then edit the file and replace PROXY_IP with the actual IP
```

If you already have a `settings.json`, merge the `"env"` block, `"model"` and `"fallbackModel"` into your existing file rather than overwriting it.

What the settings do:

| Setting | Purpose |
|---------|---------|
| `ANTHROPIC_BASE_URL` | Proxy address (no `/v1` on the end) |
| `ANTHROPIC_AUTH_TOKEN` | Proxy key. Sent as a Bearer token, so there is no "use this API key?" prompt |
| `ANTHROPIC_DEFAULT_OPUS/SONNET/HAIKU_MODEL` | Map Claude Code's `opus`, `sonnet`, `haiku` choices to proxy model names. Haiku is also used for background tasks |
| `ANTHROPIC_CUSTOM_MODEL_OPTION` (+ `_NAME`, `_DESCRIPTION`) | Always shows `fallback` in `/model`. It runs on OpenRouter, not NVIDIA NIM, so you can still use Claude Code to fix the proxy when the NIM models are retired |
| `fallbackModel` | Models Claude Code switches to when the main model is overloaded or returns a server error |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Stops telemetry, error reports and update checks to Anthropic |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | Stops sending Anthropic-only beta fields that other models reject |
| `DISABLE_PROMPT_CACHING` | Prompt caching is Anthropic-only |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | Compacts the conversation before it outgrows the backend models' context |
| `API_TIMEOUT_MS` | Allows slow free models up to 10 minutes per request |

4. Log out of claude.ai (the proxy provides its own backend):
```bash
claude /logout
```

5. Start Claude Code:
```bash
claude
```

### Option 2: Environment Variables

Set these before running Claude Code:

**Windows (PowerShell):**
```powershell
$env:ANTHROPIC_BASE_URL="http://PROXY_IP:4000"
$env:ANTHROPIC_AUTH_TOKEN="DUMMY_KEY"
claude
```

**Mac/Linux:**
```bash
export ANTHROPIC_BASE_URL=http://PROXY_IP:4000
export ANTHROPIC_AUTH_TOKEN=DUMMY_KEY
claude
```

For permanent use, add the exports to your `~/.bashrc` or `~/.zshrc`.

## Available Models

| Model Name | Backend (NVIDIA NIM unless noted) |
|------------|-----------------------------------|
| `claude-opus-5` | nemotron-3-ultra-550b |
| `claude-sonnet-5` | nemotron-3.5-super-vl-120b |
| `claude-haiku-4-5` (default) | nemotron-3.5-lightning-30b |
| `backup` | mistral-large-4 (slower) |
| `fallback` | OpenRouter `openrouter/free` router |
| `fallback-check` | Always fails over. Use it to test the fallback chain |

Newer and older Claude names (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`, `claude-fable-5-1`, `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) also work, so clients without the settings file still connect. See [config/litellm_config.yaml](../config/litellm_config.yaml) for the current list.

## Verify It Works

```bash
# From your machine, check the proxy is reachable
curl http://PROXY_IP:4000/v1/models -H "Authorization: Bearer DUMMY_KEY"
```

Should return a JSON list of available models.

## Troubleshooting

### Connection Refused
- Verify the proxy IP is reachable: `ping PROXY_IP`
- Check the proxy is running: `curl http://PROXY_IP:4000/v1/models -H "Authorization: Bearer DUMMY_KEY"`

### Authentication Errors
- Run `claude /logout` first
- Make sure `ANTHROPIC_AUTH_TOKEN` is set to `DUMMY_KEY` (exactly)
- Check `ANTHROPIC_API_KEY` is not also set to a different value

### Models Stop Working (410 Gone / 404)
Free models get retired without notice. Run `/model` and pick **Fallback (OpenRouter)**, then use Claude Code to update `config/litellm_config.yaml`, push, and restart the container.

### Multiple Machines
Any number of Claude Code clients can connect to a single proxy. Use the same settings on each machine.
