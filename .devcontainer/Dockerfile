ARG VARIANT
FROM mcr.microsoft.com/vscode/devcontainers/base:0-alpine-${VARIANT}

RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community yq

USER vscode

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.10.2 && \
    printf '. ~/.asdf/asdf.sh\n. ~/setup-asdf.sh\n' | tee -a ~/.zshrc >> ~/.bashrc

COPY setup-asdf.sh /home/vscode/setup-asdf.sh
