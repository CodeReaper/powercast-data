FROM alpine:3.20

RUN apk add --no-cache -q \
    yq-go=4.44.1-r2 \
    jq=1.7.1-r0 \
    make=4.4.1-r2 \
    shellcheck=0.10.0-r1 \
    editorconfig-checker=2.7.0-r10 \
    check-jsonschema=0.27.3-r1 \
    util-linux-misc=2.40.1-r1
