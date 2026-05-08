# Quick Start Guide

Deploy the Claude LiteLLM proxy in 5 minutes.

## Step 1: Get Your Google API Key

1. Go to https://aistudio.google.com/app/apikey
2. Click **"Create API key"**
3. Copy the key (starts with `AIza...`)

## Step 2: Deploy the Container

```bash
# Clone the repository
git clone https://github.com/rrwood/claude_litellm_proxy.git
cd claude_litellm_proxy

# Copy environment template
cp .env.example .env

# Edit network settings (adjust for your network)
nano .env
```

**Important:** Update these in `.env`:
- `CONTAINER_IP` - Choose an available IP on your network
- `NETWORK_SUBNET` - Your network subnet (e.g., 192.168.1.0/24)
- `NETWORK_GATEWAY` - Your router IP
- `USER_PASSWORD` - Change the default password!

```bash
# Build and start
docker-compose up -d

# Check it's running
docker logs litellm-proxy
```

## Step 3: Add Your API Key

SSH into the container:
```bash
ssh litellm@YOUR_CONTAINER_IP
# Password: whatever you set in USER_PASSWORD (default: changeme123)
```

Add your Google API key:
```bash
nano ~/.config/litellm/.env
```

Change this line:
```
GOOGLE_API_KEY=your_google_api_key_here
```

To your actual key:
```
GOOGLE_API_KEY=AIzaSy...your_real_key
```

Save and exit, then restart:
```bash
exit
docker-compose restart
```

## Step 4: Configure Claude Code

On your client machine:

**Windows:**
```powershell
$env:ANTHROPIC_BASE_URL="http://YOUR_CONTAINER_IP:4000"
$env:ANTHROPIC_API_KEY="DUMMY_KEY"
claude /logout
claude
```

**Linux/Mac:**
```bash
export ANTHROPIC_BASE_URL=http://YOUR_CONTAINER_IP:4000
export ANTHROPIC_API_KEY=DUMMY_KEY
claude /logout
claude
```

## Step 5: Test It

In Claude Code, try:
```
Hello! What model are you using?
```

You should get a response! 🎉

## Verify It's Working

Check the proxy logs:
```bash
docker logs -f litellm-proxy
```

You should see:
```
INFO:     192.168.x.x:xxxxx - "POST /v1/messages?beta=true HTTP/1.1" 200 OK
```

## Troubleshooting

**Container won't start:**
```bash
docker logs litellm-proxy
```

**Can't connect from client:**
```bash
# Test the proxy
curl http://YOUR_CONTAINER_IP:4000/health
```

**API key errors:**
- Make sure you edited `~/.config/litellm/.env` **inside the container**
- Restart the container after changing the API key
- Check the key is valid at https://aistudio.google.com/app/apikey

**"Quota exceeded" errors:**
- You're trying to use Gemini Pro (not free)
- Config should map to `gemini-2.5-flash` (free tier)

## Next Steps

- [CLIENT_SETUP.md](CLIENT_SETUP.md) - Configure more clients
- [README.md](README.md) - Full documentation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

## Using Portainer

If you use Portainer:

1. Create new stack
2. Name: `litellm-proxy`
3. Upload files or paste docker-compose.yml
4. Set environment variables in the Portainer UI
5. Deploy

Then follow steps 3-5 above.

## Security Tips

1. **Change the default password** in `.env` before deploying
2. **Don't commit** your `.env` file to git
3. **Firewall** - Only allow trusted IPs to port 4000
4. **SSH keys** - Set up key-based authentication (disable password auth)

Enjoy free Claude Code with Gemini! 🚀
