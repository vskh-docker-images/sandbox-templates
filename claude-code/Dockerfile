FROM docker/sandbox-templates:claude-code-docker

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        links \
    && rm -rf /var/lib/apt/lists/*

# Environment injection: loader script and env file directory
COPY scripts/agent-environment.sh /etc/agent-environment.sh
COPY scripts/agent-entrypoint.sh /usr/local/bin/agent-entrypoint.sh

RUN chmod +x /etc/agent-environment.sh /usr/local/bin/agent-entrypoint.sh \
    && mkdir -p /etc/agent-environment.d

# Hook into sandbox-persistent.sh so claude's bash tool also gets the environment
RUN grep -qF '. /etc/agent-environment.sh' /etc/sandbox-persistent.sh 2>/dev/null \
    || echo '. /etc/agent-environment.sh' >> /etc/sandbox-persistent.sh

USER agent

# Replace the claude symlink with a wrapper that sources the environment
# before delegating to the real binary (renamed to .claude-real)
RUN mv ~/.local/bin/claude ~/.local/bin/.claude-real
COPY --chown=agent:agent scripts/claude-wrapper.sh /home/agent/.local/bin/claude
RUN chmod +x ~/.local/bin/claude

ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
