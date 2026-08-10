# Claude LiteLLM Proxy

A Docker container running LiteLLM proxy that translates Anthropic API calls to NVIDIA NIM API. Point Claude Code CLI at this proxy to use free NVIDIA NIM models instead of paid Claude API credits. Deploy once via Portainer or Docker Compose, then connect multiple Claude Code clients from any machine on your network. All Claude model requests (Opus, Sonnet, Haiku) are automatically mapped to NVIDIA NIM models with support for SSH access, auto-start on boot, and simple environment-based configuration.

## Example Deployment

One proxy server can serve multiple Claude Code clients across different platforms:

```
                           ┌─────────────────────────────────┐
                           │   Docker Server (Portainer)     │
                           │                                 │
                           │  ┌───────────────────────────┐  │
    ┌──────────────────────┼─►│  LiteLLM Proxy Container  │  │
    │                      │  │  (192.168.1.100:4000)     │──┼──► NVIDIA NIM API
    │                      │  │                           │  │    (Free Tier)
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
- Get an NVIDIA NIM API Key
- Go to build.nvidia.com and create a free NVIDIA account
- Complete  verification via SMS or email (some regions may have trouble receiving the code — try a different number if needed)
- Navigate to any model page and click “Get API Key” (or go to the API Keys section)
- Click “Create API Key” and copy it — it’s only shown once
The key format looks like nvapi-...


## Quick Start

### Portainer Deployment (Recommended)

**The easiest way - no command line needed!**

1. **Download** [.env.example](https://github.com/rrwood/claude_litellm_proxy/blob/main/.env.example), save as `.env`, and customize:
   ```env
   CONTAINER_IP=192.168.1.100          # Change to available IP
   USER_PASSWORD=your_secure_password  # Change this!
   NETWORK_SUBNET=192.168.1.0/24      # Your network
   NETWORK_GATEWAY=192.168.1.1        # Your router
   ```

2. **Create stack** in Portainer:
   - Stacks → Add stack → Name: `litellm-proxy`
   - Build method: **Repository**
   - Repository URL: `https://github.com/rrwood/claude_litellm_proxy`
   - Reference: `refs/heads/main`
   - Compose path: `docker-compose.no-ui.external-network.yml` (for existing macvlan networks) or `docker-compose.no-ui.yml` (to auto-create network)
   - Upload your `.env` file

3. **Add your API keys** in Portainer:
   - Go to **Stacks → litellm-proxy → Environment variables**
   - Click **"Load variables from .env file"** and upload a local `.env` file containing your keys:
     ```env
     NVIDIA_NIM_API_KEY=nvapi-your_actual_key
     GOOGLE_API_KEY=your_google_key          # optional, for Gemini models
     ```
   - Or edit the `NVIDIA_NIM_API_KEY` variable inline

4. **Click "Update the stack"** to restart with your keys — done!

> **Note:** API keys are stored in Portainer's stack variables and survive image rebuilds and container restarts. The model config (`litellm_config.yaml`) is pulled from GitHub automatically on startup, so model mapping changes only need a container restart.

Detailed guide: [docs/PORTAINER.md](docs/PORTAINER.md)

---

### Docker Compose Deployment (Alternative)

**For command-line users:**

#### Prerequisites

- Docker and Docker Compose installed
- A network with static IP capability (or use bridge networking)
- NVIDIA NIM API key from https://build.nvidia.com/nim (free)

#### 1. Clone and Configure

```bash
git clone https://github.com/rrwood/claude_litellm_proxy.git
cd claude_litellm_proxy

# Copy and edit environment file
cp .env.example .env
nano .env  # Update network settings for your environment
```

#### 2. Deploy

```bash
docker-compose up -d
```

### 3. Configure NVIDIA NIM API Key

Set the API key in your `.env` file:
```env
NVIDIA_NIM_API_KEY=nvapi-your_actual_key
GOOGLE_API_KEY=your_google_key    # optional, for Gemini models
```

Restart the container:
```bash
docker-compose restart
```

### 4. Configure Claude Code Clients

On your client machine (Windows/Linux/Mac), set environment variables:

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

Then run:
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
- **[docs/CLIENT_SETUP.md](docs/CLIENT_SETUP.md)** - Configure Claude Code clients
- **[docs/litellm-output-config-patch.md](docs/litellm-output-config-patch.md)** - Patch for `output_config` leak to non-Anthropic providers

## Configuration

### Network Settings

The default `docker-compose.no-ui.yml` auto-creates a macvlan network for direct network access. Update `.env` with your network settings:

- `CONTAINER_IP` - Static IP for the container
- `NETWORK_SUBNET` - Your network subnet (e.g., 192.168.111.0/24)
- `NETWORK_GATEWAY` - Your network gateway (e.g., 192.168.111.254)
- `NETWORK_INTERFACE` - Host interface (e.g., enp2s0, eth0)
- `NETWORK_IP_RANGE` - IP range for macvlan (e.g., 192.168.111.48/29)

### Using Existing Macvlan Network

If you already have a `macvlan-for-direct-access` network:

**Portainer:** Use compose path `docker-compose.no-ui.external-network.yml`

**Docker Compose:**
```bash
docker-compose -f docker-compose.no-ui.external-network.yml up -d
```

### Using Bridge Networking (Alternative)

If you don't have static IP capability, use bridge networking with port mapping. See the bridge networking section in [docs/PORTAINER.md](docs/PORTAINER.md).

### Security

**Change the default password immediately:**

```bash
ssh litellm@YOUR_CONTAINER_IP
passwd
```

Or set `USER_PASSWORD` in `.env` before deploying.

## Available Models

The proxy maps these Claude models to NVIDIA NIM models:
- `claude-haiku-4-5` → `meta/llama-3.3-70b-instruct` (default)
- `claude-sonnet-5` → `deepseek-ai/deepseek-v4-pro`
- `claude-opus-5` → `nvidia/nemotron-3-ultra-550b-a55b`

Legacy model names (`claude-haiku-4-5-20251001`, `claude-sonnet-4-6`, `claude-opus-4-7`) are also supported as aliases.

You can also request `gemini-2.5-flash` directly (requires GOOGLE_API_KEY).

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
- `CONFIG_REPO_URL` - Git repo URL (default: this repo)
- `CONFIG_REPO_BRANCH` - Branch to pull from (default: `main`)
- `CONFIG_REPO_PATH` - Path to config file in the repo (default: `config/litellm_config.yaml`)

Alternatively, SSH into the container and edit `~/.config/litellm/litellm_config.yaml` directly, then restart LiteLLM (changes will be overwritten on next container restart if `CONFIG_REPO_URL` is set).

## Limitations

- **Alpine-only**: This project uses Alpine Linux. The official Debian-based LiteLLM database image fails with exit code 132 (SIGILL) on some x86_64 hosts. If you need the Admin UI, you may need a different host or a custom Alpine build.
- **Free tier only**: Uses NVIDIA NIM free tier models. For higher limits, check NVIDIA NIM pricing.
- **Rate limits**: Subject to NVIDIA NIM free tier rate limits (see https://build.nvidia.com/nim)
- **Model differences**: NVIDIA NIM models are not identical to Claude models

## How It Works

```
Claude Code CLI → LiteLLM Proxy → NVIDIA NIM API
                  (translates Anthropic API → NVIDIA NIM API)
```

LiteLLM acts as a proxy that:
1. Receives requests in Anthropic's API format
2. Translates them to NVIDIA NIM API format
3. Sends responses back in Anthropic's format

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
