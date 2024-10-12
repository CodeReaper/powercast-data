FROM alpine:3.20

RUN apk add yq-go jq make shellcheck editorconfig-checker check-jsonschema

RUN mkdir -p /schemas && wget -O /schemas/dependabot-2.0.json https://json.schemastore.org/dependabot-2.0.json