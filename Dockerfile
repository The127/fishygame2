# syntax=docker/dockerfile:1

# Stage 1: export the Web build with headless Godot.
FROM debian:bookworm-slim AS export

# Keep in sync with GODOT_VERSION / checksums in .github/workflows/ci.yml.
ARG GODOT_VERSION=4.7.2
ARG GODOT_SHA512=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
ARG GODOT_TEMPLATES_SHA512=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/godot
RUN base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable" \
    && curl -fsSL -o godot.zip "${base}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && echo "${GODOT_SHA512}  godot.zip" | sha512sum -c - \
    && unzip -q godot.zip \
    && install -m 755 "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && curl -fsSL -o templates.tpz "${base}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && echo "${GODOT_TEMPLATES_SHA512}  templates.tpz" | sha512sum -c - \
    && unzip -q templates.tpz \
    && mkdir -p /root/.local/share/godot/export_templates \
    && mv templates "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
    && rm -rf /tmp/godot

WORKDIR /project
COPY . .
RUN mkdir -p build/web \
    && godot --headless --import \
    && godot --headless --export-release Web build/web/index.html \
    && test -s build/web/index.html && test -s build/web/index.wasm && test -s build/web/index.pck

# Stage 2: serve the static export.
FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=export /project/build/web /usr/share/nginx/html
EXPOSE 80
