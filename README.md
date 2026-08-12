# Claude LiteLLM Proxy

A Docker container running LiteLLM proxy that translates Anthropic API calls to free AI models. Point Claude Code CLI at this proxy to use free NVIDIA NIM and OpenRouter models instead of paid Claude API credits. Deploy once via Portainer or Docker Compose, then connect multiple Claude Code clients from any machine on your network. All Claude model requests (Opus, Sonnet, Haiku) are automatically mapped to free models, with automatic fallback to OpenRouter if NIM is unavailable. Model config is pulled from GitHub on startup, so mapping changes only need a container restart — no rebuild.

## Example Deployment

One proxy server can serve multiple Claude Code clients across different platforms:

```
                           ┌─────────────────────────────────┐
                           │   Docker Server (Portainer)     │
                           │                                 │
                           │  ┌───────────────────────────┐  │
    ┌──────────────────────┼─►│  LiteLLM Proxy Container  │  │
    │                      │  │  (192.168.1.100:4000)     │──┼──► NVIDIA NIM API (primary)
    │                      │  │                           │──┼──► OpenRouter API (fallback)
    │                      │  │  • Deployed via GitHub    │  │
    │                      │  │  • Auto-start on boot     │  │
    │  Claude Code CLI     │  └───────────────────────────┘  │
    │  Clients             │                                 │
    │                      └─────────────────────────────────┘
    │
    │  ┌────────────────────────────────────────┐
    ├──┤  Windows Desktop                       │
    │  │  • Claude Code CLI                     │
    │  │  • VS Code extension                   │
    │  │  • General development                 │
    │  └────────────────────────────────────────┘
    │
    │  ┌────────────────────────────────────────┐
    ├──┤  Linux Laptop                          │
    │  │  • Claude Code CLI                     │
    │  │  • Terminal-based development          │
    │  └────────────────────────────────────────┘
    │
    │  ┌────────────────────────────────────────┐
    └──┤  Home Assistant OS                     │
       │  ┌──────────────────────────────────┐  │
       │  │  Dev Container (Docker)          │  │
       │  │  • Claude Code CLI               │  │
       │  │  • Home Assistant development    │  │
       │  └──────────────────────────────────┘  │
       └────────────────────────────────────────┘
```

### Before you start 
- **NVIDIA NIM API Key** (primary models)
  - Go to build.nvidia.com and create a free NVIDIA account
  - Complete verification via SMS or email (some regions may have trouble receiving the code — try a different number if needed)
  - Navigate to any model page and click “Get API Key” (or go to the API Keys section)
  - Click “Create API Key” and copy it — it’s only shown once
  - The key format looks like `nvapi-...`
- **OpenRouter API Key** (fallback, optional but recommended)
  - Go to openrouter.ai and create a free account (no payment method needed)
  - Go to Keys > create a new key
  - The key format looks like `sk-or-v1-...`


## Quick Start

### Portainer (Recommended)

The easiest way — no command line needed. Point Portainer at this GitHub repo, upload a `.env` file with your network settings and API keys, and deploy. Portainer handles building, environment variables, and one-click updates.

Full walkthrough: **[docs/PORTAINER.md](docs/PORTAINER.md)**

### Docker Compose

For command-line users — clone the repo, configure `.env`, and run:

```bash
git clone https://github.com/rrwood/claude_litellm_proxy.git
cd claude_litellm_proxy
cp .env.example .env
nano .env  # Set network settings + API keys
docker-compose -f docker-compose.no-ui.yml up -d --build
```

### Not Using Portainer?

Dockge and Coolify are lightweight alternatives that can also manage this container. See **[docs/portainer-alternatives.md](docs/portainer-alternatives.md)** for setup instructions and a comparison.

### Configure Claude Code Clients

On each client machine, point Claude Code at the proxy:

**Windows (PowerShell):**
```powershell
$env:ANTHROPIC_BASE_URL="http://YOUR_CONTAINER_IP:4000"
$env:ANTHROPIC_API_KEY="DUMMY_KEY"
```

**Linux/Mac (Bash):**
```bash
export ANTHROPIC_BASE_URL=http://YOUR_CONTAINER_IP:4000
export ANTHROPIC_API_KEY=DUMMY_KEY
```

```bash
claude /logout  # Logout of claude.ai first
claude          # Start using the proxy!
```

See [docs/CLIENT_SETUP.md](docs/CLIENT_SETUP.md) for detailed client configuration.

## Windows Quick Start

The `windows_scripts/` folder provides a one-command launcher for Windows users:

1. **Copy** `windows_scripts/.env.example` to `windows_scripts/.env` and set your proxy IP:
   ```env
   ANTHROPIC_BASE_URL=http://YOUR_CONTAINER_IP:4000
   ANTHROPIC_API_KEY=DUMMY_KEY
   ```

2. **Run** the launcher from PowerShell:
   ```powershell
   .\windows_scripts\Start-Claude.ps1
   ```

The script loads environment variables from `.env` (current directory or script directory) and then launches `claude` with any arguments you pass through. You can also place `Start-Claude.ps1` and `.env` anywhere in your `PATH` for convenience.

## LiteLLM `output_config` Patch

When routing Claude Code requests through LiteLLM to **non-Anthropic providers** (Nvidia NIM, Bedrock, etc.), LiteLLM's Anthropic pass-through adapter leaks the `output_config` parameter to the downstream provider, causing errors like:

```
Unsupported parameter(s): `output_config`
```

LiteLLM's `drop_params: true` setting does **not** catch this parameter because it flows through a lower layer. The fix requires patching three files in the LiteLLM installation to strip `output_config` before it reaches the provider.

### Applying the Patch

An idempotent bash script is provided at `scripts/patch-litellm-output-config.sh`:

```bash
chmod +x scripts/patch-litellm-output-config.sh
./scripts/patch-litellm-output-config.sh
sudo systemctl restart litellm
```

The script auto-locates the LiteLLM install via Python and is safe to re-run. For Docker deployments, either call the script from your entrypoint or bake the patches into your `Dockerfile` — see [docs/litellm-output-config-patch.md](docs/litellm-output-config-patch.md) for the full Dockerfile `RUN` lines and manual patching steps.

- Confirmed on: **LiteLLM 1.83.14**
- Upstream issue: [BerriAI/litellm#22797](https://github.com/BerriAI/litellm/issues/22797)

## Documentation

- **[docs/PORTAINER.md](docs/PORTAINER.md)** - Complete Portainer deployment guide (Recommended)
- **[docs/portainer-alternatives.md](docs/portainer-alternatives.md)** - Deploy without Portainer (Dockge, Coolify, plain Docker Compose)
- **[docs/CLIENT_SETUP.md](docs/CLIENT_SETUP.md)** - Configure Claude Code clients
- **[docs/litellm-output-config-patch.md](docs/litellm-output-config-patch.md)** - Patch for `output_config` leak to non-Anthropic providers

## Available Models

### Primary Models (NVIDIA NIM)

| Claude Model | NIM Backend | Typical Speed |
|---|---|---|
| `claude-opus-5` | nvidia/nemotron-3-ultra-550b-a55b | ~3 sec |
| `claude-sonnet-5` | deepseek-ai/deepseek-v4-flash-0731 | ~60 sec |
| `claude-haiku-4-5` (default) | nvidia/llama-3.3-nemotron-super-49b-v1.5 | ~30 sec |

Legacy model names (`claude-haiku-4-5-20251001`, `claude-sonnet-4-6`, `claude-opus-4-7`) are also supported as aliases.

### Fallback Model (OpenRouter)

If any NIM model fails (retired, rate-limited, down), LiteLLM automatically retries on OpenRouter:

| Fallback | OpenRouter Backend | Typical Speed |
|---|---|---|
| `fallback` | nvidia/nemotron-3-super-120b-a12b:free | ~90 sec |

The fallback is slow but keeps you working while you find replacement models. Requires `OPENROUTER_API_KEY`.

### Additional Models

You can also request `gemini-2.5-flash` directly (requires `GOOGLE_API_KEY`).

## Swagger API Documentation

The proxy includes built-in interactive API documentation via Swagger UI for managing models and testing endpoints.

**Access:** `http://YOUR_CONTAINER_IP:4000/`

**Features:**
- Browse all available API endpoints
- Test API calls interactively
- View request/response schemas
- Add/modify model mappings via `/model/new` API
- Check model health via `/model/info`

**Authentication:** Use `DUMMY_KEY` as Bearer token (set in config as `master_key`)

**Note:** A full Admin UI with database features is available in LiteLLM's official Docker images, but requires Debian-based systems (see Limitations).

## Changing Model Mappings

The proxy pulls `config/litellm_config.yaml` from this GitHub repo on every container startup via the `CONFIG_REPO_URL` environment variable (enabled by default in docker-compose). To update model mappings:

1. Edit `config/litellm_config.yaml` in this repo
2. Push the change
3. Restart the container (no rebuild needed)

To override the config source, set these environment variables in your `.env` or Portainer stack:
- `CONFIG_REPO_URL` - Git repo URL (default: this repo). Set to `none` to disable config pull entirely.
- `CONFIG_REPO_BRANCH` - Branch to pull from (default: `main`)
- `CONFIG_REPO_PATH` - Path to config file in the repo (default: `config/litellm_config.yaml`)

If you set `CONFIG_REPO_URL=none`, you can SSH into the container and edit `~/.config/litellm/litellm_config.yaml` directly. Changes will persist across restarts since nothing overwrites them.

## Limitations

- **Alpine-only**: This project uses Alpine Linux. The official Debian-based LiteLLM database image fails with exit code 132 (SIGILL) on some x86_64 hosts. If you need the Admin UI, you may need a different host or a custom Alpine build.
- **Free tier only**: Uses NVIDIA NIM and OpenRouter free tier models. Response times vary (3-90 seconds depending on model and load).
- **Rate limits**: Subject to NVIDIA NIM and OpenRouter free tier rate limits
- **Model differences**: NVIDIA NIM models are not identical to Claude models

## How It Works

```
Claude Code CLI → LiteLLM Proxy → NVIDIA NIM API (primary)
                                 ↘ OpenRouter API (fallback)
```

LiteLLM acts as a proxy that:
1. Receives requests in Anthropic's API format
2. Translates them to the backend provider's format (NIM or OpenRouter)
3. If the primary model fails, automatically retries on the fallback
4. Sends responses back in Anthropic's format

Model config is pulled from GitHub on container startup (`CONFIG_REPO_URL`), so updating model mappings is: edit config, push, restart container.

## Contributing

Issues and pull requests welcome!

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [LiteLLM](https://github.com/BerriAI/litellm) - The proxy powering this project
- [NVIDIA NIM](https://build.nvidia.com/nim) - Free AI API
- [Anthropic Claude](https://claude.ai/) - Claude Code CLI

## Support

For issues and questions:
- Open an issue on GitHub
- Visit LiteLLM docs: https://docs.litellm.ai/
