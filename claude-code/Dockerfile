FROM docker/sandbox-templates:claude-code-docker

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        links \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/agent-environment.sh /etc/agent-environment.sh
COPY scripts/agent-entrypoint.sh /usr/local/bin/agent-entrypoint.sh

RUN chmod +x /etc/agent-environment.sh /usr/local/bin/agent-entrypoint.sh \
    && mkdir -p /etc/agent-environment.d

USER agent

ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
