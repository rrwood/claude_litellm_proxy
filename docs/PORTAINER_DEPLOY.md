# Deploying to Portainer - Clear Cache Instructions

## The Problem
Exit code 132 errors are often caused by Docker using cached build layers. Even though the Dockerfile is updated, Portainer may use old cached layers.

## Solution: Clear Build Cache in Portainer

### Method 1: Prune Builder Cache (Recommended)
1. In Portainer, go to **"Images"** (under Docker on your endpoint)
2. Click **"Unused Images"** or **"Dangling Images"**
3. Delete any old `litellm-proxy` images
4. Go to your **Terminal** or **SSH into Portainer host**
5. Run:
   ```bash
   docker builder prune -af
   ```
6. Then redeploy your stack

### Method 2: Force Rebuild in Stack
1. Before deploying, go to **Stacks** → **litellm-proxy**
2. **Stop** the stack
3. **Remove** the stack completely
4. In Portainer host terminal, run:
   ```bash
   docker system prune -a
   ```
5. Recreate the stack with your compose file

### Method 3: Use BuildKit Args (Already Added)
The compose file now includes `CACHEBUST: 20260517` which forces cache invalidation.
- To force a fresh build, change this date in your stack's compose file
- Change `CACHEBUST: 20260517` to `CACHEBUST: 20260518` (or any different value)

## Current Deployment Files

Choose one based on your network setup:

- **With Admin UI + External Network**: `docker-compose.external-network.yml` (default/recommended)
- **With Admin UI + Auto Network**: `docker-compose.yml`  
- **No Admin UI + Auto Network**: `docker-compose.no-ui.yml`

## Quick Deploy Steps

1. Clear Docker cache (see methods above)
2. In Portainer:
   - Go to **Stacks**
   - Create new stack or edit existing
   - Paste contents of `docker-compose.external-network.yml`
   - Add your environment variables
   - Click **Deploy**

## Environment Variables

Make sure these are set in Portainer stack:
```
USERNAME=litellm
USER_PASSWORD=yourpassword
CONTAINER_HOSTNAME=litellm-proxy
CONTAINER_NAME=litellm-proxy
CONTAINER_IP=192.168.111.50
TIMEZONE=UTC
```

## Verifying Fix Applied

The new Dockerfile.ui includes:
- Platform specification: `--platform=linux/amd64`
- Improved apt-get with `DEBIAN_FRONTEND=noninteractive`
- Cache busting with `CACHEBUST` arg

If you still get exit code 132, the cache wasn't cleared properly.
