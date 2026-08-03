#!/bin/bash
# Debug version of entrypoint - prints each step

echo "===== ENTRYPOINT DEBUG START ====="
echo "Current user: $(whoami)"
echo "USERNAME env: ${USERNAME}"
echo "USER_PASSWORD env: ${USER_PASSWORD}"

# Get the actual username from build args (defaults to litellm)
USERNAME=${USERNAME:-litellm}
USER_PASSWORD=${USER_PASSWORD:-changeme123}
USER_HOME="/home/${USERNAME}"

echo "===== Step 1: Setting user password ====="
if echo "${USERNAME}:${USER_PASSWORD}" | chpasswd; then
    echo "✓ Password set successfully"
else
    echo "✗ FAILED to set password (exit code: $?)"
fi

echo "===== Step 2: Starting SSH service ====="
if /usr/sbin/sshd; then
    echo "✓ SSH started successfully"
else
    echo "✗ FAILED to start SSH (exit code: $?)"
fi

echo "===== Step 3: Checking .env file ====="
if [ ! -f "$USER_HOME/.config/litellm/.env" ]; then
    echo "Creating .env from example..."
    cp "$USER_HOME/.config/litellm/.env.example" "$USER_HOME/.config/litellm/.env"
    chown ${USERNAME}:${USERNAME} "$USER_HOME/.config/litellm/.env"
    echo "✓ .env created"
else
    echo "✓ .env already exists"
fi

echo "===== Step 4: Starting LiteLLM proxy ====="
echo "Command: su - ${USERNAME} -c $USER_HOME/.config/litellm/start-litellm.sh"
su - ${USERNAME} -c "$USER_HOME/.config/litellm/start-litellm.sh" &
LITELLM_PID=$!
echo "✓ LiteLLM started with PID: $LITELLM_PID"

echo "===== Step 5: Container ready ====="
echo "Container ready. SSH: port 22, LiteLLM: port 4000"
echo "Tailing /dev/null to keep container alive..."
tail -f /dev/null
