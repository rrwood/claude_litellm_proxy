FROM alpine:latest

# Build arguments with defaults
ARG USERNAME=litellm
ARG USER_PASSWORD=changeme123
ARG CONTAINER_HOSTNAME=litellm-proxy

# Make USERNAME available at runtime
ENV USERNAME=${USERNAME}

# Install system packages
RUN apk update && apk add --no-cache \
    bash \
    curl \
    python3 \
    py3-pip \
    openssh \
    sudo \
    shadow \
    tzdata

# Create user
RUN useradd -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set hostname (done late to ensure no conflicts)
RUN echo "${CONTAINER_HOSTNAME}" > /etc/hostname

# Configure SSH
RUN mkdir -p /run/sshd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    ssh-keygen -A

# Install LiteLLM and dependencies
RUN pip3 install --no-cache-dir --break-system-packages \
    litellm \
    aiohttp fastapi uvicorn pydantic jinja2 click \
    python-dotenv httpx openai tiktoken tokenizers \
    gunicorn uvloop backoff pyyaml orjson apscheduler \
    fastapi-sso pyjwt python-multipart cryptography \
    pynacl websockets boto3 azure-identity azure-storage-blob \
    mcp litellm-proxy-extras litellm-enterprise \
    restrictedpython rich polars soundfile rq jsonschema \
    importlib-metadata fastuuid

# Switch to user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Create LiteLLM configuration directory
RUN mkdir -p /home/${USERNAME}/.config/litellm

# Copy LiteLLM configuration files
COPY --chown=${USERNAME}:${USERNAME} config/litellm_config.yaml /home/${USERNAME}/.config/litellm/
COPY --chown=${USERNAME}:${USERNAME} config/.env.example /home/${USERNAME}/.config/litellm/
COPY --chown=${USERNAME}:${USERNAME} scripts/start-litellm.sh /home/${USERNAME}/.config/litellm/
RUN chmod +x /home/${USERNAME}/.config/litellm/start-litellm.sh

# Add PATH for Python local binaries
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/${USERNAME}/.bashrc

# Setup welcome message
USER root
COPY scripts/welcome-motd.sh /etc/profile.d/welcome.sh
RUN chmod +x /etc/profile.d/welcome.sh

# Copy entrypoint script
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE 22 4000

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
