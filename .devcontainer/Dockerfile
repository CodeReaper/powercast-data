ARG VARIANT="3.15"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-alpine-${VARIANT}

RUN git config --global --add safe.directory /workspaces/

RUN apk update

RUN apk add --no-cache python3
