FROM docker/sandbox-templates:shell-docker

USER root

RUN apt update && apt install -y --no-install-recommends \
        links \
        vim \
        git \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV EDITOR=vim

COPY scripts/agent-environment.sh /etc/agent-environment.sh
COPY scripts/agent-entrypoint.sh /usr/local/bin/agent-entrypoint.sh
COPY scripts/hermes-launch.sh /usr/local/bin/hermes-launch

RUN chmod +x /etc/agent-environment.sh \
    /usr/local/bin/agent-entrypoint.sh \
    /usr/local/bin/hermes-launch \
    && mkdir -p /etc/agent-environment.d \
    && { grep -qF '. /etc/agent-environment.sh' /etc/sandbox-persistent.sh 2>/dev/null \
        || echo '. /etc/agent-environment.sh' >> /etc/sandbox-persistent.sh; } \
    && { grep -qF 'PATH="/home/agent/bin:' /etc/sandbox-persistent.sh 2>/dev/null \
        || echo 'PATH="/home/agent/bin:/home/agent/.local/bin:$PATH"' >> /etc/sandbox-persistent.sh; } \
    && { grep -qF 'EDITOR=' /etc/sandbox-persistent.sh 2>/dev/null \
        || echo 'EDITOR=vim' >> /etc/sandbox-persistent.sh; }

USER agent

ENV HERMES_HOME=/home/agent/.hermes

RUN mkdir -p /home/agent/bin

RUN curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh \
    | bash -s -- --skip-setup

COPY --chown=agent:agent scripts/hermes-wrapper.sh /home/agent/bin/hermes
RUN chmod +x /home/agent/bin/hermes

ENV PATH="/home/agent/bin:/home/agent/.local/bin:${PATH}"

ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["hermes-launch", "--yolo"]
