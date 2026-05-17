# LiteLLM Admin UI Deployment Troubleshooting History

## Session Date: 2026-05-17

### Initial Problem
Attempted to deploy the LiteLLM proxy with Admin UI support using the official LiteLLM database image. Deployment failed with:
```
Failed to deploy a stack: Service litellm-proxy Building failed to solve: 
process "/bin/sh -c apt-get update && apt-get install -y openssh-server sudo nano curl && rm -rf /var/lib/apt/lists/*" 
did not complete successfully: exit code: 132
```

### Background
- **Working before today:** Alpine-based LiteLLM proxy (no UI) was successfully deployed
- **Goal:** Add Admin UI support using official database image
- **Deployment method:** Portainer pulling from git repository
- **Host architecture:** x86_64/amd64 (verified)
- **Network:** macvlan external network at 192.168.111.50

### Troubleshooting Attempts

#### 1. Platform Specification (Commit 7172263)
**Changes:**
- Added `--platform=linux/amd64` to Dockerfile
- Added platform specification to docker-compose files
- Improved apt-get with `DEBIAN_FRONTEND=noninteractive`
- Added cache-busting mechanism

**Result:** ❌ Same error - apt-get still failed with exit code 132

#### 2. Docker Cache Clearing
**Actions:**
- Cleared Docker build cache: `docker builder prune -af`
- Cleared system: `docker system prune -a`
- Pre-pulled base image: `docker pull --platform=linux/amd64 docker.litellm.ai/berriai/litellm-database:main-stable`

**Result:** ❌ Base image pulled successfully, but build still failed

#### 3. Removed Cache Bust (Commit 82356a5)
**Changes:**
- Removed `RUN echo "Cache bust: ${CACHEBUST}"` line that was also failing

**Result:** ❌ apt-get install still failed with exit code 132

#### 4. Network Issue (Discovered)
**Problem:** During troubleshooting, macvlan network was deleted
**Solution:** Recreated network with:
```bash
docker network create -d macvlan --subnet="192.168.111.0/24" --gateway="192.168.111.254" \
  --ip-range="192.168.111.48/29" -o parent="enp2s0" macvlan-for-direct-access
```

#### 5. Minimal UI Version (Commit b5b6504)
**Changes:**
- Created `Dockerfile.ui.minimal` - skipped SSH installation entirely
- Created `entrypoint-no-ssh.sh` - entrypoint without SSH dependencies
- Only essential packages, no apt-get for SSH/sudo

**Result:** ❌ Failed on even simpler command: `RUN echo "${CONTAINER_HOSTNAME}" > /etc/hostname`

#### 6. Barebone Version (Commit 45a2cd8)
**Changes:**
- Created `Dockerfile.ui.barebone` with ZERO RUN commands
- Just uses base image as-is with ENV variables only

**Result:** ⚠️ Build succeeded but container crash-looped with exit code 132 on base image's own entrypoint

### Root Cause Identified

**Exit code 132 = Illegal Instruction**

The official LiteLLM database image `docker.litellm.ai/berriai/litellm-database:main-stable` (Debian-based) is fundamentally incompatible with the user's Docker host environment.

**Evidence:**
- Host architecture is correct (x86_64/amd64) - verified with `uname -m`
- Base image pulls successfully
- ANY command execution fails - even `echo`, `apt-get`, or the image's own entrypoint
- Alpine-based images work fine on the same host

**Likely cause:** CPU instruction set incompatibility between the Debian base image's compiled binaries and the host CPU, or kernel incompatibility.

### Solution

**Use the Alpine-based version** that was working before attempting UI addition:
- **Compose file:** `docker-compose.no-ui.external-network.yml`
- **Dockerfile:** `Dockerfile` (Alpine-based)
- **Trade-off:** No Admin UI, but fully functional LiteLLM proxy

### Future Options for Admin UI

#### Option 1: SSH Access to Existing Container
- Deploy Alpine version with SSH enabled (already configured in Dockerfile)
- Manage via CLI and configuration files
- No web UI, but full functionality

#### Option 2: Build Custom Alpine-based UI
**Complexity:** High
**Requirements:**
- Start from Alpine base image
- Manually install Prisma on Alpine
- Set up PostgreSQL or SQLite
- Configure LiteLLM with database support
- Build/include UI components

**Why not done yet:** Significant effort, and the official image should work but doesn't on this host.

#### Option 3: Investigate Host Compatibility
- Update Docker version
- Check kernel version
- Try different base images (Ubuntu, different Debian versions)
- Run on different host

### Files Created During Troubleshooting

**Working files:**
- `docker-compose.no-ui.external-network.yml` - Alpine version with external network ✅
- `Dockerfile` - Alpine-based, no UI ✅
- `recreate-macvlan.sh` - Script to recreate network

**Failed attempts (kept for reference):**
- `Dockerfile.ui` - Original UI version with SSH
- `Dockerfile.ui.minimal` - UI without SSH
- `Dockerfile.ui.barebone` - UI with no RUN commands
- `Dockerfile.ui.test` - Bare base image test
- `docker-compose.external-network.yml` - UI version with external network
- `docker-compose.ui-minimal.external-network.yml`
- `docker-compose.ui-barebone.external-network.yml`
- `entrypoint-no-ssh.sh` - Entrypoint without SSH dependencies

**Documentation:**
- `PORTAINER_DEPLOY.md` - Deployment instructions
- `TROUBLESHOOTING_HISTORY.md` - This file

### Commits Made

1. `7172263` - Fix Docker build exit code 132 error (platform + cache fixes)
2. `82356a5` - Remove cache bust line causing exit code 132
3. `b6b1e4c` - Add no-UI version with external network for Alpine fallback
4. `b5b6504` - Add minimal UI Dockerfile options without SSH
5. `9f0fc4a` - Add UI minimal compose for external network (no SSH)
6. `45a2cd8` - Add barebone UI Dockerfile with zero RUN commands

### Next Steps (For Future Session)

See `NEXT_SESSION_PLAN.md` for detailed plan.

**Immediate action:** Deploy working Alpine version:
1. Ensure macvlan network exists
2. Deploy using `docker-compose.no-ui.external-network.yml` in Portainer
3. Access at `http://192.168.111.50:4000` and SSH at `192.168.111.50:22`
