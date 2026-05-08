# GitHub Setup Instructions

Follow these steps to push this project to GitHub.

## 1. Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `claude_litellm_proxy`
3. Description: `LiteLLM proxy for using Claude Code CLI with free Gemini API`
4. **Public** repository (so others can use it)
5. **Do NOT** initialize with README, .gitignore, or license (we already have these)
6. Click **"Create repository"**

## 2. Configure Git Identity (One-time)

```bash
cd ~/code/claude_litellm_proxy

# Set your GitHub username and email
git config user.name "Your GitHub Username"
git config user.email "your-github-email@example.com"

# Fix the commit author
git commit --amend --reset-author --no-edit
```

## 3. Add Remote and Push

Replace `YOUR_USERNAME` with your GitHub username:

```bash
git remote add origin https://github.com/YOUR_USERNAME/claude_litellm_proxy.git
git branch -M main
git push -u origin main
```

**If using SSH:**
```bash
git remote add origin git@github.com:YOUR_USERNAME/claude_litellm_proxy.git
git branch -M main
git push -u origin main
```

## 4. Update README.md

After pushing, update the clone URL in README.md and other docs:

```bash
# Find and replace YOUR_USERNAME with your actual username
sed -i 's/YOUR_USERNAME/your-actual-username/g' README.md
sed -i 's/YOUR_USERNAME/your-actual-username/g' QUICKSTART.md

git add README.md QUICKSTART.md
git commit -m "Update GitHub username in documentation"
git push
```

## 5. Add Repository Topics

On GitHub, go to your repository and add these topics (for discoverability):
- `litellm`
- `claude`
- `gemini`
- `anthropic`
- `docker`
- `proxy`
- `ai`
- `llm`

## 6. Enable Issues

1. Go to Settings → General
2. Scroll to "Features"
3. Enable "Issues"

## 7. Add Repository Description

At the top of your GitHub repo page:
- Click the ⚙️ gear icon next to "About"
- Description: `Docker proxy for using Claude Code CLI with free Google Gemini API via LiteLLM`
- Website: (leave blank or add docs link)
- Topics: (already added in step 5)

## What's Included

Your repository now contains:

```
claude_litellm_proxy/
├── .gitignore                    # Ignores .env and other secrets
├── .env.example                  # Template for Docker environment
├── docker-compose.yml            # Docker Compose configuration
├── Dockerfile                    # Container build instructions
├── LICENSE                       # MIT License
├── README.md                     # Main documentation
├── QUICKSTART.md                 # Quick setup guide
├── CLIENT_SETUP.md               # Client configuration guide
├── config/
│   ├── .env.example             # Template for Google API key
│   └── litellm_config.yaml      # LiteLLM configuration
└── scripts/
    ├── entrypoint.sh            # Container startup script
    └── start-litellm.sh         # LiteLLM launcher

```

## Privacy Check

The following have been sanitized (no personal info):
- ✅ All IP addresses are examples (192.168.1.x)
- ✅ No actual API keys (only placeholders)
- ✅ Username is generic (`litellm`)
- ✅ No commit history from original project
- ✅ `.env` is gitignored (won't be committed)

## Sharing the Project

Once pushed to GitHub, anyone can use it:

```bash
git clone https://github.com/YOUR_USERNAME/claude_litellm_proxy.git
cd claude_litellm_proxy
cp .env.example .env
# Edit .env with network settings
docker-compose up -d
```

## Optional: Add a Banner Image

Create a screenshot or diagram showing:
```
[Claude Code CLI] → [LiteLLM Proxy] → [Google Gemini API]
                     (Docker Container)
```

Upload to GitHub and add to README.md:
```markdown
![Architecture](docs/architecture.png)
```

## Next Steps

- Share the repository URL with others
- Create releases for stable versions
- Add to awesome-litellm lists
- Post on Reddit, HN, etc.

Enjoy sharing your work! 🚀
