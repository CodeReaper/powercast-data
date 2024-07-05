FROM mcr.microsoft.com/devcontainers/base:alpine-3.20

COPY --from=mikefarah/yq:4.41.1 /usr/bin/yq /usr/local/bin/yq
COPY --from=koalaman/shellcheck-alpine:v0.9.0 /bin/shellcheck /usr/local/bin/shellcheck
COPY --from=mstruebing/editorconfig-checker:2.7.2 /usr/bin/ec /usr/local/bin/ec
COPY --from=maniator/gh:v2.44.1 /usr/bin/gh /usr/local/bin/gh

USER vscode

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0 && \
    printf '. ~/.asdf/asdf.sh\n. ~/setup-asdf.sh\n' | tee -a ~/.zshrc >> ~/.bashrc

COPY setup-asdf.sh /home/vscode/setup-asdf.sh
