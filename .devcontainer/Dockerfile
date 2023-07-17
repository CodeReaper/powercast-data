ARG VARIANT
FROM mcr.microsoft.com/vscode/devcontainers/base:0-alpine-${VARIANT}

COPY --from=mikefarah/yq:4.30.2 /usr/bin/yq /usr/local/bin/yq
COPY --from=koalaman/shellcheck:v0.8.0 /bin/shellcheck /usr/local/bin/shellcheck
COPY --from=mstruebing/editorconfig-checker:2.7.0 /usr/bin/ec /usr/local/bin/ec
COPY --from=maniator/gh:v2.30.0 /usr/bin/gh /usr/local/bin/gh

USER vscode

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.10.2 && \
    printf '. ~/.asdf/asdf.sh\n. ~/setup-asdf.sh\n' | tee -a ~/.zshrc >> ~/.bashrc

COPY setup-asdf.sh /home/vscode/setup-asdf.sh
