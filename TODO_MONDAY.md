# TODO - Monday 2026-05-12

## Update LiteLLM Container with New Google API Key

### Background
- Old Google account had severe quota restrictions (5-20 requests/day instead of 1,500/day)
- Created new Google account with fresh API key
- Need to update the running container

### Steps to Complete

1. **Update API key in container:**
   ```bash
   ssh rwood@192.168.111.50
   nano ~/.config/litellm/.env
   # Replace GOOGLE_API_KEY=<old_key> with new key from new account
   # Save (Ctrl+X, Y, Enter)
   ```

2. **Restart LiteLLM:**
   ```bash
   pkill -f litellm
   ~/.config/litellm/start-litellm.sh &
   ```

3. **Test with Claude Code CLI:**
   ```bash
   claude "hello"
   ```

4. **Verify quota in new account:**
   - Login to GCP Console with new Google account
   - Navigate to: https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas
   - Confirm quotas show:
     - Requests per minute: 15 (not 5)
     - Requests per day: 1,500 (not 20)

5. **Test from multiple clients:**
   - Windows desktop
   - Linux laptop
   - Any other Claude Code clients

### Expected Results
- ✅ No more "quota exceeded" errors after a few requests
- ✅ Can use Claude Code normally throughout the day
- ✅ 1,500 requests/day should be plenty for development use

### Notes
- New Google account should have full free tier access
- Old account had restrictions due to expired GCP trial
- Keep new API key secure (don't share in conversations!)

### If Still Getting Quota Errors
1. Check which project the new key is in
2. Verify Generative Language API is enabled
3. Check regional restrictions: https://ai.google.dev/gemini-api/docs/available-regions
4. Try creating API key in GCP Console instead of AI Studio

---

**Reminder:** Delete all exposed API keys from Friday's session if not already done.
