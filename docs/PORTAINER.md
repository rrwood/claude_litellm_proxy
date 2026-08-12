# Portainer Deployment Guide

**The easiest way to deploy Claude LiteLLM Proxy**

Deploy this proxy in minutes using Portainer's stack feature with GitHub repository integration and environment file upload.

## Prerequisites

- Portainer installed and running
- Access to your Docker host's network configuration
- NVIDIA NIM API key from https://build.nvidia.com/nim

## Quick Deploy (Recommended)

### Step 1: Create .env File Locally

Download and customize the environment file on your local machine:

1. Download `.env.example` from https://github.com/rrwood/claude_litellm_proxy/blob/main/.env.example
2. Save as `.env` on your local machine
3. Edit with your network settings:

```env
# Container Settings
USERNAME=litellm
USER_PASSWORD=your_secure_password_here    # ⚠️ CHANGE THIS!
CONTAINER_NAME=litellm-proxy
HOSTNAME=litellm-proxy
CONTAINER_IP=192.168.1.100                 # ⚠️ Change to available IP

# Network Settings (adjust for your network)
NETWORK_INTERFACE=enp2s0                   # Your Docker host interface (eth0, enp2s0, ens33, etc.)
NETWORK_SUBNET=192.168.111.0/24           # Your network subnet
NETWORK_GATEWAY=192.168.111.254           # Your router IP
NETWORK_IP_RANGE=192.168.111.48/29        # IP range for this stack (.48-.55)

# Timezone
TIMEZONE=America/New_York                 # Your timezone
```

**Important:** 
- Change `USER_PASSWORD` to a strong password
- Set `CONTAINER_IP` to an available IP on your network (e.g., .49-.54 from the /29 range)
- Adjust network settings to match your environment
- Find your interface with: `ip addr show` on the Docker host

### Step 2: Create Stack in Portainer

1. **Navigate to Stacks**
   - Portainer → Stacks → **Add stack**

2. **Configure Stack**
   - **Name:** `litellm-proxy`
   - **Build method:** Select **"Repository"**

3. **Repository Settings**
   - **Repository URL:** `https://github.com/rrwood/claude_litellm_proxy`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `docker-compose.no-ui.yml` (or `docker-compose.no-ui.external-network.yml` if using existing network)
   - **Authentication:** Not required (public repository)

4. **Upload Environment File**
   - Scroll to **"Environment variables"**
   - Click **"Load variables from .env file"**
   - Select your customized `.env` file
   - Verify variables are loaded

5. **Deploy**
   - Click **"Deploy the stack"**
   - Wait for deployment to complete

### Step 3: Add API Keys

1. Go to **Stacks → litellm-proxy → Environment variables**
2. Click **"Load variables from .env file"** and upload a file containing your keys:
   ```env
   NVIDIA_NIM_API_KEY=nvapi-your_actual_key
   OPENROUTER_API_KEY=sk-or-v1-your_key    # optional, enables fallback
   GOOGLE_API_KEY=your_google_key           # optional, for Gemini models
   ```
   Or add them inline using **"+ add an environment variable"**
3. Click **"Update the stack"** to restart with your keys

API keys are stored in Portainer's stack variables and survive image rebuilds and container restarts.

### Step 4: Verify Deployment

Check the logs:
- Portainer → Stacks → litellm-proxy → **Container logs**

You should see:
```
LiteLLM: Proxy initialized with Config, Set models:
    claude-opus-4-7
    claude-haiku-4-5-20251001
    claude-sonnet-4-5-20250929
    nvidia_nim models
INFO:     Uvicorn running on http://0.0.0.0:4000 (Press CTRL+C to quit)
```

Test the proxy:
```bash
curl http://YOUR_CONTAINER_IP:4000/health
# Should return: {"status":"ok"}
```

## Alternative: Manual Environment Variables

If you prefer not to upload a file, you can enter variables manually in Portainer:

1. In the stack creation form, under **"Environment variables"**
2. Click **"+ add an environment variable"** for each:

```
USERNAME = litellm
USER_PASSWORD = your_secure_password
CONTAINER_NAME = litellm-proxy
HOSTNAME = litellm-proxy
CONTAINER_IP = 192.168.111.50
NETWORK_INTERFACE = enp2s0
NETWORK_SUBNET = 192.168.111.0/24
NETWORK_GATEWAY = 192.168.111.254
NETWORK_IP_RANGE = 192.168.111.48/29
TIMEZONE = America/New_York
NVIDIA_NIM_API_KEY = nvapi-your_actual_key
OPENROUTER_API_KEY = sk-or-v1-your_key
```

## Network Configuration

### Using Macvlan (Default)

The default configuration uses macvlan networking for direct network access. The container gets its own IP address on your network.

**Requirements:**
- Static IP capability on your network
- `CONTAINER_IP` must be outside your DHCP range
- Docker host must support macvlan

**Finding your network settings:**

```bash
# On your Docker host
ip addr show                    # Find your interface (enp2s0, eth0, ens33, etc.)
ip route | grep default         # Find your gateway
```

### Using Existing Macvlan Network

If you already have a `macvlan-for-direct-access` network created on your Docker host, use the alternative compose file:

1. **In Portainer stack configuration**, change:
   - **Compose path:** `docker-compose.no-ui.external-network.yml`

2. **In your .env file**, you only need:
   ```env
   CONTAINER_IP=192.168.111.50
   USER_PASSWORD=your_secure_password
   ```

3. Deploy normally - Portainer will use your existing network instead of creating a new one.

**When to use this:**
- You have multiple containers sharing the same macvlan network
- The network was created manually or by another stack
- You want to reuse an existing network configuration

### Using Bridge Networking (Alternative)

If macvlan doesn't work for your setup, use bridge networking:

1. **Before deploying**, modify `docker-compose.yml` in the stack editor:

```yaml
services:
  litellm-proxy:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        USERNAME: ${USERNAME:-litellm}
        USER_PASSWORD: ${USER_PASSWORD:-changeme123}
    container_name: ${CONTAINER_NAME:-litellm-proxy}
    hostname: ${HOSTNAME:-litellm-proxy}
    ports:
      - "4000:4000"    # LiteLLM API
      - "2222:22"      # SSH (mapped to avoid conflict)
    restart: unless-stopped
    environment:
      - TZ=${TIMEZONE:-UTC}
```

2. **Remove the networks section** entirely

3. Access via:
   - LiteLLM API: `http://DOCKER_HOST_IP:4000`
   - SSH: `ssh -p 2222 litellm@DOCKER_HOST_IP`

## Model Config Updates

The container automatically pulls `litellm_config.yaml` from GitHub on every startup. This is controlled by the `CONFIG_REPO_URL` environment variable, which defaults to this project's repo in the docker-compose files.

**To pick up model mapping changes:** just restart the container in Portainer. No rebuild needed.

**To override the config source**, add these environment variables to your stack:
- `CONFIG_REPO_URL` — Git repo URL (default: `https://github.com/rrwood/claude_litellm_proxy.git`)
- `CONFIG_REPO_BRANCH` — Branch to pull from (default: `main`)
- `CONFIG_REPO_PATH` — Path to config file in the repo (default: `config/litellm_config.yaml`)

## Updating the Stack

Use "Pull and redeploy" when the Dockerfile, scripts, or dependencies change. This is separate from model config updates above — those only need a restart.

### Method 1: Pull and Redeploy (Recommended)

1. Portainer → Stacks → litellm-proxy
2. Click **"Pull and redeploy"**
3. Portainer will pull the latest code from GitHub and rebuild

### Method 2: Manual Update

1. Stop the stack
2. Delete the stack (keeps volumes)
3. Recreate following Step 2 above

API keys stored in Portainer's stack variables are preserved when you delete and recreate a stack using the same name and environment variables.

## Troubleshooting

### Stack Fails to Deploy

**Check logs:**
- Portainer → Stacks → litellm-proxy → Container logs

**Common issues:**

1. **IP address conflict:**
   ```
   Error: address already in use
   ```
   → Change `CONTAINER_IP` to a different IP

2. **Network doesn't exist:**
   ```
   Error: network litellm-network not found
   ```
   → Portainer will create it automatically, but verify `NETWORK_INTERFACE` is correct

3. **Build fails:**
   ```
   Error pulling image
   ```
   → Check GitHub repository is accessible from your Portainer instance

### Container Starts but LiteLLM Not Running

**SSH into container:**
```bash
ssh litellm@YOUR_CONTAINER_IP
ps aux | grep litellm
```

**Check for errors:**
- Verify `NVIDIA_NIM_API_KEY` is set in Portainer stack environment variables

**Manually start:**
```bash
~/.config/litellm/start-litellm.sh
```

### Can't SSH to Container

1. **Check container is running:**
   - Portainer → Containers → litellm-proxy → Status

2. **Check network connectivity:**
   ```bash
   ping YOUR_CONTAINER_IP
   ```

3. **Verify password:**
   - Use the password from `USER_PASSWORD` in your `.env`

4. **Check SSH is running:**
   - Portainer → Containers → litellm-proxy → **>_ Console**
   - Run: `sudo /usr/sbin/sshd -T` (verify SSH config)

### Quota Exceeded Error

```
You exceeded your current quota, please check your plan and billing details
```

- You're using a paid NVIDIA NIM model (e.g., `a paid NIM model`)
- The config should use free-tier NVIDIA NIM models
- Check `config/litellm_config.yaml` in the repository

## Security Recommendations

1. **Change default password:**
   - Set `USER_PASSWORD` in `.env` before deploying
   - Or change after deployment: `ssh litellm@IP` → `passwd`

2. **Firewall rules:**
   - Allow port 4000 only from trusted IPs
   - Allow port 22 only from management machines

3. **SSH keys (recommended):**
   ```bash
   ssh-copy-id litellm@YOUR_CONTAINER_IP
   ```

4. **Keep .env secure:**
   - Don't commit to version control
   - Store in a secure location
   - Use password manager for `USER_PASSWORD`

## Environment Variables Reference

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `USERNAME` | `litellm` | Container user | No |
| `USER_PASSWORD` | `changeme123` | User password for SSH | **Yes** |
| `CONTAINER_NAME` | `litellm-proxy` | Docker container name | No |
| `HOSTNAME` | `litellm-proxy` | Container hostname | No |
| `CONTAINER_IP` | `192.168.1.100` | Static IP for container | **Yes** |
| `NETWORK_INTERFACE` | `eth0` | Docker host network interface | **Yes** |
| `NETWORK_SUBNET` | `192.168.1.0/24` | Network subnet | **Yes** |
| `NETWORK_GATEWAY` | `192.168.1.1` | Network gateway IP | **Yes** |
| `NETWORK_IP_RANGE` | `192.168.1.100/29` | IP range for macvlan | **Yes** |
| `TIMEZONE` | `UTC` | Container timezone | No |
| `NVIDIA_NIM_API_KEY` | *(none)* | NVIDIA NIM API key | **Yes** |
| `OPENROUTER_API_KEY` | *(none)* | OpenRouter API key (fallback) | No |
| `GOOGLE_API_KEY` | *(none)* | Google API key (Gemini models) | No |
| `CONFIG_REPO_URL` | This project's repo | Git repo to pull config from on startup | No |
| `CONFIG_REPO_BRANCH` | `main` | Branch to pull config from | No |
| `CONFIG_REPO_PATH` | `config/litellm_config.yaml` | Path to config file in repo | No |

## Post-Deployment

After successful deployment:

1. **Configure clients:** See [CLIENT_SETUP.md](CLIENT_SETUP.md)
2. **Test the proxy:** See [QUICKSTART.md](QUICKSTART.md) Step 5
3. **Monitor usage:** Check logs in Portainer

## Benefits of Portainer Deployment

✅ **No command line needed** - Everything in the UI  
✅ **GitHub integration** - Pull latest updates easily  
✅ **Environment file upload** - Easy configuration  
✅ **Visual monitoring** - See logs, stats, and status  
✅ **Easy updates** - "Pull and redeploy" button  
✅ **Persistent config** - Survives restarts  

## Next Steps

- [CLIENT_SETUP.md](CLIENT_SETUP.md) - Configure Claude Code clients
- [README.md](../README.md) - Full documentation

---

**Questions or issues?** Open an issue at https://github.com/rrwood/claude_litellm_proxy/issues
