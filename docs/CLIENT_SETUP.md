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

If you already have a `settings.json`, merge the `"env"` block into your existing file rather than overwriting it.

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
$env:ANTHROPIC_API_KEY="DUMMY_KEY"
claude
```

**Mac/Linux:**
```bash
export ANTHROPIC_BASE_URL=http://PROXY_IP:4000
export ANTHROPIC_API_KEY=DUMMY_KEY
claude
```

For permanent use, add the exports to your `~/.bashrc` or `~/.zshrc`.

## Available Models

Once connected, these models are available via `/model` in Claude Code:

| Model Name | Backend |
|------------|---------|
| `claude-haiku-4-5-20251001` | NVIDIA NIM llama-3.3-70b (default) |
| `claude-sonnet-4-6` | NVIDIA NIM deepseek-v4-pro |
| `claude-opus-4-7` | NVIDIA NIM nemotron-3-ultra-550b |

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
- Make sure `ANTHROPIC_API_KEY` is set to `DUMMY_KEY` (exactly)
- Check no other Anthropic env vars are set (`ANTHROPIC_AUTH_TOKEN`, etc.)

### Multiple Machines
Any number of Claude Code clients can connect to a single proxy. Use the same settings on each machine.
