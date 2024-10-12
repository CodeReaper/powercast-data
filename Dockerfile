FROM alpine:3.20

RUN apk add -q yq-go jq make shellcheck editorconfig-checker check-jsonschema util-linux-misc

RUN mkdir -p /schemas && wget -qO /schemas/dependabot-2.0.json https://json.schemastore.org/dependabot-2.0.json
