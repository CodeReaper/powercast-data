ARG VARIANT="3.15"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-alpine-${VARIANT}

RUN wget https://github.com/mikefarah/yq/releases/download/v4.25.1/yq_linux_amd64 -O yq_linux_amd64 \
    && mv yq_linux_amd64 /usr/bin/yq \
    && chmod +x /usr/bin/yq
