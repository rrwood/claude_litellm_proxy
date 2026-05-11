# Client Setup Guide

Configure Claude Code CLI to use your LiteLLM proxy for free NVIDIA NIM access.

## Prerequisites

- Claude Code CLI installed ([Download](https://claude.ai/download))
- LiteLLM proxy running (see [README.md](README.md))
- Proxy IP address (e.g., 192.168.1.100)

## Important: Logout First

Claude Code needs **only** the API key, not claude.ai login:

```bash
claude /logout
```

When prompted to add an API key, say **"No"** for now. We'll configure via environment variables.

## Configuration

### Windows (PowerShell)

#### Temporary (Current Session Only)

```powershell
$env:ANTHROPIC_BASE_URL="http://192.168.1.100:4000"
$env:ANTHROPIC_API_KEY="DUMMY_KEY"

# Test it
claude
```

#### Permanent (User Environment Variables)

1. Press `Win + X` → **System** → **Advanced system settings**
2. Click **Environment Variables**
3. Under **User variables**, click **New** and add:
   - Variable: `ANTHROPIC_BASE_URL`
   - Value: `http://192.168.1.100:4000`
4. Add another:
   - Variable: `ANTHROPIC_API_KEY`
   - Value: `DUMMY_KEY`
5. Click **OK** and restart PowerShell

### Linux/Mac (Bash/Zsh)

#### Temporary (Current Session Only)

```bash
export ANTHROPIC_BASE_URL=http://192.168.1.100:4000
export ANTHROPIC_API_KEY=DUMMY_KEY

# Test it
claude
```

#### Permanent (Shell Profile)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Claude LiteLLM Proxy
export ANTHROPIC_BASE_URL=http://192.168.1.100:4000
export ANTHROPIC_API_KEY=DUMMY_KEY
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Test the Connection

```bash
claude
```

Then ask: **"What model are you?"**

The response will say "Claude" (LiteLLM translates the identity), but you can verify it's an NVIDIA NIM model by asking:
- "What is your knowledge cutoff date?" (varies by model)
- "Who created you?" (varies by model, e.g. Alibaba, Moonshot, Qwen)

## Using Different Proxy IPs

Replace `192.168.1.100` with your actual proxy container IP address.

To find your container IP:
```bash
docker inspect litellm-proxy | grep IPAddress
```

## Troubleshooting

### Connection Refused

**Check if LiteLLM is running:**
```bash
# From your client machine
curl http://192.168.1.100:4000/health
```

Should return: `{"status":"ok"}`

If not, check the container:
```bash
docker logs litellm-proxy
```

### Authentication Errors

Make sure:
1. You logged out of claude.ai: `claude /logout`
2. `ANTHROPIC_API_KEY` is set to `DUMMY_KEY` (exactly)
3. No other API keys are set in your environment

### Wrong Model/Errors

Clear environment and re-set:

**Windows:**
```powershell
Remove-Item Env:\ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\ANTHROPIC_MODEL -ErrorAction SilentlyContinue
$env:ANTHROPIC_BASE_URL="http://192.168.1.100:4000"
$env:ANTHROPIC_API_KEY="DUMMY_KEY"
```

**Linux/Mac:**
```bash
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_MODEL
export ANTHROPIC_BASE_URL=http://192.168.1.100:4000
export ANTHROPIC_API_KEY=DUMMY_KEY
```

## Multiple Machines

You can connect as many Claude Code clients as you want to a single proxy. Just set the same environment variables on each machine.

## Network Access

Make sure your client machine can reach the proxy:
```bash
ping 192.168.1.100
```

If using firewall, allow port 4000 on the proxy container.

## Benefits

✅ **Free** - Use NVIDIA NIM's generous free tier  
✅ **Centralized** - One API key, multiple machines  
✅ **Fast** - NVIDIA NIM models are very fast  
✅ **Transparent** - Claude Code works exactly the same  

## Next Steps

- Customize model mappings in the proxy config
- Set up SSH keys for secure access
- Configure startup scripts for your workflow

See [README.md](README.md) for more information.
