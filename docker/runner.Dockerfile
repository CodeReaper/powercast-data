FROM alpine:3.23

RUN apk add --no-cache -q yq-go jq make shellcheck editorconfig-checker check-jsonschema util-linux-misc
