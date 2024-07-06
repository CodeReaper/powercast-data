FROM alpine:3.20

RUN apk add yq-go jq make shellcheck editorconfig-checker
