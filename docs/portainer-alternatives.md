# Alternatives to Portainer

This guide explains what Portainer does for the claude-litellm-proxy deployment, and how to achieve the same thing with other tools.

## What Portainer Does for Us

Portainer handles four things in this project:

1. **Builds the image from GitHub** — Portainer's "Repository" build method points at the GitHub repo, pulls the Dockerfile and docker-compose.yml, and builds the image directly. No need to clone the repo locally.

2. **Stores API keys** — Environment variables (NVIDIA_NIM_API_KEY, OPENROUTER_API_KEY, etc.) are saved in Portainer's stack variables. They persist across image rebuilds and container restarts.

3. **One-click rebuild** — The "Pull and redeploy" button fetches the latest code from GitHub and rebuilds the image. Useful when the Dockerfile, entrypoint scripts, or Python dependencies change.

4. **Web UI for monitoring** — View container logs, restart containers, and check status without touching a terminal.

### What the Container Handles Itself

The container's entrypoint script already pulls `litellm_config.yaml` (model mappings) from GitHub on every startup via the `CONFIG_REPO_URL` environment variable. This means **model mapping updates only need a container restart**, regardless of which tool manages the container. This works the same way with every alternative below.

To disable config pull and manage config manually inside the container, set `CONFIG_REPO_URL=none`.

The distinction matters: you need a tool that can **rebuild the image** when the Dockerfile changes (less frequent), but config updates are automatic on restart.

---

## Option 1: Docker Compose (CLI)

**Best for:** Users comfortable with the command line. No extra software needed.

### Initial Setup

```bash
# Clone the repo
git clone https://github.com/rrwood/claude_litellm_proxy.git
cd claude_litellm_proxy

# Create your environment file
cp .env.example .env
nano .env  # Set CONTAINER_IP, USER_PASSWORD, network settings

# Add API keys to .env
echo "NVIDIA_NIM_API_KEY=nvapi-your_key_here" >> .env
echo "OPENROUTER_API_KEY=sk-or-v1-your_key_here" >> .env

# Build and start
docker-compose -f docker-compose.no-ui.yml up -d --build
```

### Updating Model Config

Model mappings update automatically on restart — no rebuild needed:

```bash
docker-compose -f docker-compose.no-ui.yml restart
```

### Updating the Image (When Dockerfile Changes)

Pull latest code from GitHub and rebuild:

```bash
cd claude_litellm_proxy
git pull
docker-compose -f docker-compose.no-ui.yml up -d --build
```

Your `.env` file is outside the container so API keys are preserved.

### Automation Script

Save this as `update-proxy.sh` next to your clone for a one-command update:

```bash
#!/bin/bash
cd "$(dirname "$0")/claude_litellm_proxy"
git pull
docker-compose -f docker-compose.no-ui.yml up -d --build
echo "Proxy updated and running"
```

To check for updates automatically, add a cron job:

```bash
# Check for updates daily at 3am, only rebuild if there are changes
0 3 * * * cd ~/claude_litellm_proxy && git fetch && [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ] && git pull && docker-compose -f docker-compose.no-ui.yml up -d --build
```

---

## Option 2: Dockge

**Best for:** Users who want a simple web UI without Portainer's complexity.

[Dockge](https://github.com/louislam/dockge) is a lightweight Docker Compose manager with a clean web interface. It manages compose stacks, environment variables, and container lifecycle — similar to Portainer's stack feature but much simpler.

### What Dockge Provides

- Web UI for managing docker-compose stacks
- Built-in environment variable editor
- Container logs, restart, start/stop from the UI
- Compose file editor in the browser
- Lightweight (single container, ~100MB)

### What Dockge Does Not Provide

- No native Git integration — you clone the repo manually
- No "pull and redeploy from GitHub" button — you run `git pull` yourself

Since the container already pulls model config from GitHub on startup, Dockge handles the day-to-day (restart to pick up config changes, view logs, manage env vars). You only need the command line for image rebuilds when the Dockerfile changes.

### Install Dockge

```bash
# Create directories
mkdir -p /opt/dockge /opt/stacks
cd /opt/dockge

# Download and start Dockge
curl -fsSL https://get.dockge.io | bash
```

Dockge runs at `http://your-server:5001`.

### Deploy the Proxy via Dockge

1. Clone the repo on your Docker host:
   ```bash
   git clone https://github.com/rrwood/claude_litellm_proxy.git /opt/stacks/litellm-proxy
   ```

2. Open Dockge at `http://your-server:5001`

3. Click **"+ Compose"** — Dockge should detect the stack in `/opt/stacks/litellm-proxy`

4. If not auto-detected, create a new stack named `litellm-proxy` and paste the contents of `docker-compose.no-ui.yml`

5. Add environment variables in the UI:
   - `CONTAINER_IP` — your chosen IP
   - `USER_PASSWORD` — a secure password
   - `NVIDIA_NIM_API_KEY` — your NIM key
   - `OPENROUTER_API_KEY` — your OpenRouter key (optional)
   - Network settings as needed

6. Click **"Deploy"**

### Updating

**Model config changes** (most common): Click the restart button in Dockge. The container pulls fresh config from GitHub on startup.

**Dockerfile/image changes** (less common):
```bash
cd /opt/stacks/litellm-proxy
git pull
```
Then click **"Restart"** in Dockge (or **"Down"** then **"Up"** to force a rebuild).

---

## Option 3: Coolify

**Best for:** Users who want full Git-native deployment with automatic rebuilds.

[Coolify](https://coolify.io) is a self-hosted PaaS (like Heroku or Vercel) that deploys directly from GitHub repositories. It is the closest alternative to Portainer's Git integration — and in some ways goes further, offering webhook-triggered auto-deploys.

### What Coolify Provides

- Deploys directly from a GitHub repo (like Portainer's "Repository" build)
- Automatic rebuilds when you push to GitHub (via webhooks)
- Environment variable management in the UI
- Container logs, health checks, restart
- Full web UI with deployment history

### What Coolify Adds Over Portainer

- Webhook auto-deploy — push to GitHub and Coolify rebuilds automatically
- Deployment rollback — revert to a previous build
- Built-in reverse proxy (Traefik) with automatic HTTPS

### Install Coolify

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Coolify runs at `http://your-server:8000`. Follow the setup wizard to create your admin account.

### Deploy the Proxy via Coolify

1. In Coolify, go to **Projects** and create a new project

2. Add a new **Resource** → **Docker Compose**

3. Connect your GitHub account (or use the public repo URL):
   - Repository: `https://github.com/rrwood/claude_litellm_proxy`
   - Branch: `main`
   - Docker Compose file: `docker-compose.no-ui.yml`

4. Add environment variables:
   - `CONTAINER_IP`, `USER_PASSWORD`, `NVIDIA_NIM_API_KEY`, etc.

5. Deploy

### Updating

**Model config changes**: Restart the container in Coolify. The entrypoint pulls fresh config from GitHub.

**Dockerfile/image changes**: Push to GitHub — Coolify detects the change via webhook and rebuilds automatically. Or click **"Redeploy"** in the UI.

### Considerations

Coolify is heavier than Portainer or Dockge — it runs its own PostgreSQL database, Redis, and Traefik proxy. It is best suited if you plan to host multiple services, not just this one container. If you only need the litellm-proxy, Dockge or plain Docker Compose is simpler.

Coolify's built-in Traefik proxy may conflict with the macvlan networking this project uses. You may need to use bridge networking with port mapping instead, or configure Coolify to skip its proxy for this service.

---

## Comparison

| Feature | Docker Compose | Dockge | Coolify | Portainer |
|---|---|---|---|---|
| Web UI | No | Yes | Yes | Yes |
| Git-based deploy | Manual `git pull` | Manual `git pull` | Automatic (webhooks) | "Pull and redeploy" button |
| Env var management | `.env` file | UI editor | UI editor | UI editor |
| Container logs | `docker logs` | UI | UI | UI |
| Restart/rebuild | CLI commands | UI buttons | UI or automatic | UI buttons |
| Setup complexity | None (just Docker) | Low (one container) | Medium (multiple services) | Low (one container) |
| Resource overhead | None | ~100MB | ~500MB+ | ~200MB |
| Auto-rebuild on push | With cron (see above) | No | Yes (webhooks) | No |

### Recommendation

- **Just want it running**: Docker Compose CLI — clone, configure `.env`, `docker-compose up -d --build`
- **Want a simple web UI**: Dockge — lightweight, compose-focused, easy to set up
- **Want full Git automation**: Coolify — auto-deploys on push, deployment history, rollback
- **Already using Portainer**: Stay with Portainer — see [PORTAINER.md](PORTAINER.md)

All options work equally well for day-to-day use because the container handles config updates internally. The main difference is how you trigger image rebuilds when the Dockerfile changes.
