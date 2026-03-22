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
# and has ~/bin at the front of PATH (matching the container ENV set below).
RUN grep -qF '. /etc/agent-environment.sh' /etc/sandbox-persistent.sh 2>/dev/null \
    || echo '. /etc/agent-environment.sh' >> /etc/sandbox-persistent.sh
RUN grep -qF 'PATH="/home/agent/bin:' /etc/sandbox-persistent.sh 2>/dev/null \
    || echo 'PATH="/home/agent/bin:$PATH"' >> /etc/sandbox-persistent.sh

USER agent

# Install wrapper into ~/bin, which is prepended to PATH so it intercepts
# the 'claude' command. The real binary in ~/.local/bin is left untouched,
# so Claude's self-update mechanism continues to work correctly.
RUN mkdir -p ~/bin
COPY --chown=agent:agent scripts/claude-wrapper.sh /home/agent/bin/claude
RUN chmod +x ~/bin/claude

ENV PATH="/home/agent/bin:${PATH}"

ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
