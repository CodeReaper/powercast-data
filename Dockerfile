FROM alpine:3.21

RUN apk add --no-cache -q yq-go jq make shellcheck editorconfig-checker check-jsonschema util-linux-misc
