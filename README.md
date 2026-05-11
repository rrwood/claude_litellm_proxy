# Claude LiteLLM Proxy

A Docker container running LiteLLM proxy that translates Anthropic API calls to Google's Gemini API. Point Claude Code CLI at this proxy to use free Gemini 2.5 Flash instead of paid Claude API credits. Deploy once via Portainer or Docker Compose, then connect multiple Claude Code clients from any machine on your network. All Claude model requests (Opus, Sonnet, Haiku) are automatically mapped to Gemini 2.5 Flash with support for SSH access, auto-start on boot, and simple environment-based configuration.

## Example Deployment

One proxy server can serve multiple Claude Code clients across different platforms:

```
                           ┌─────────────────────────────────┐
                           │   Docker Server (Portainer)     │
                           │                                 │
                           │  ┌───────────────────────────┐  │
    ┌──────────────────────┼─►│  LiteLLM Proxy Container  │  │
    │                      │  │  (192.168.1.100:4000)     │──┼──► Google Gemini API
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

**Benefits:**
- ✅ Single Google API key shared across all devices
- ✅ Consistent model access from any machine
- ✅ Easy to manage (update config once, affects all clients)
- ✅ No API keys stored on client machines

## Quick Start

### 🚀 Portainer Deployment (Recommended)

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
   - Compose path: `docker-compose.yml` (or `docker-compose.external-network.yml` for existing networks)
   - Upload your `.env` file

3. **Deploy** and SSH to add Google API key:
   ```bash
   ssh litellm@192.168.1.100  # Use your CONTAINER_IP
   nano ~/.config/litellm/.env
   # Add: GOOGLE_API_KEY=your_actual_key
   ```

4. **Restart** in Portainer and you're done! 🎉

📖 **Detailed guide:** [PORTAINER.md](PORTAINER.md)

---

### 🐳 Docker Compose Deployment (Alternative)

**For command-line users:**

#### Prerequisites

- Docker and Docker Compose installed
- A network with static IP capability (or use bridge networking)
- Google API key from https://aistudio.google.com/app/apikey (free)

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

### 3. Configure Google API Key

SSH into the container:
```bash
ssh litellm@YOUR_CONTAINER_IP
# Default password: changeme123 (change this!)
```

Edit the API key:
```bash
nano ~/.config/litellm/.env
# Add your Google API key
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

See [CLIENT_SETUP.md](CLIENT_SETUP.md) for detailed client configuration.

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

The script auto-locates the LiteLLM install via Python and is safe to re-run. For Docker deployments, either call the script from your entrypoint or bake the patches into your `Dockerfile` — see [litellm-output-config-patch.md](litellm-output-config-patch.md) for the full Dockerfile `RUN` lines and manual patching steps.

- Confirmed on: **LiteLLM 1.83.14**
- Upstream issue: [BerriAI/litellm#22797](https://github.com/BerriAI/litellm/issues/22797)

## Documentation

- **[PORTAINER.md](PORTAINER.md)** - Complete Portainer deployment guide ⭐ **Recommended**
- **[QUICKSTART.md](QUICKSTART.md)** - Fast docker-compose deployment
- **[CLIENT_SETUP.md](CLIENT_SETUP.md)** - Configure Claude Code clients
- **[litellm-output-config-patch.md](litellm-output-config-patch.md)** - Patch for `output_config` leak to non-Anthropic providers
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## Configuration

### Network Settings

The default `docker-compose.yml` **auto-creates** a macvlan network for direct network access. Update `.env` with your network settings:

- `CONTAINER_IP` - Static IP for the container
- `NETWORK_SUBNET` - Your network subnet (e.g., 192.168.111.0/24)
- `NETWORK_GATEWAY` - Your network gateway (e.g., 192.168.111.254)
- `NETWORK_INTERFACE` - Host interface (e.g., enp2s0, eth0)
- `NETWORK_IP_RANGE` - IP range for macvlan (e.g., 192.168.111.48/29)

### Using Existing Macvlan Network

If you already have a `macvlan-for-direct-access` network:

**Portainer:** Use compose path `docker-compose.external-network.yml`

**Docker Compose:**
```bash
docker-compose -f docker-compose.external-network.yml up -d
```

### Using Bridge Networking (Alternative)

If you don't have static IP capability, use bridge networking with port mapping. See [BRIDGE_NETWORKING.md](BRIDGE_NETWORKING.md).

### Security

**Change the default password immediately:**

```bash
ssh litellm@YOUR_CONTAINER_IP
passwd
```

Or set `USER_PASSWORD` in `.env` before deploying.

## Available Models

The proxy maps these Claude models to Gemini 2.5 Flash:
- `claude-opus-4-7` → `gemini-2.5-flash`
- `claude-sonnet-4-5-20250929` → `gemini-2.5-flash`
- `claude-haiku-4-5-20251001` → `gemini-2.5-flash`

You can also request `gemini-2.5-flash` directly.

## Limitations

- **Free tier only**: Uses Gemini 2.5 Flash (free). For Gemini Pro, upgrade your Google API plan.
- **Rate limits**: Subject to Google's free tier rate limits (see https://ai.google.dev/pricing)
- **Model differences**: Gemini 2.5 Flash is not identical to Claude models

## How It Works

```
Claude Code CLI → LiteLLM Proxy → Google Gemini API
                  (translates Anthropic API → Gemini API)
```

LiteLLM acts as a proxy that:
1. Receives requests in Anthropic's API format
2. Translates them to Google's Gemini API format
3. Sends responses back in Anthropic's format

## Contributing

Issues and pull requests welcome!

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [LiteLLM](https://github.com/BerriAI/litellm) - The proxy powering this project
- [Google Gemini](https://ai.google.dev/) - Free AI API
- [Anthropic Claude](https://claude.ai/) - Claude Code CLI

## Support

For issues and questions:
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Open an issue on GitHub
- Visit LiteLLM docs: https://docs.litellm.ai/
