# One architecture and immutable VHS/Chromium/font bytes for every contributor.
FROM ghcr.io/charmbracelet/vhs@sha256:3afed459e6d7860f6bb8b9a22ae29d5927d628dac6e30f32a250113406a348b9

# A dated archive also pins transitive package dependencies.
RUN rm /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
        'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260918T000000Z trixie main' \
        'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/20260918T000000Z trixie-security main' \
        > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        fzf=0.60.3-1+b2 \
        git-delta=0.18.2-4+b1 \
        python3-pil=11.1.0-5+deb13u4 \
        tmux=3.5a-3 gcc libc6-dev make xz-utils curl \
    && rm -rf /var/lib/apt/lists/*

COPY tools.json install.py /tmp/build/
RUN python3 /tmp/build/install.py && rm -rf /tmp/build
RUN apt-get update && apt-get install -y --no-install-recommends git ripgrep fd-find \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/tools/go/bin:$PATH GOROOT=/opt/tools/go \
    GOPROXY=off GOSUMDB=off GOCACHE=/tmp/go-cache GOPATH=/tmp/gopath \
    FLUME_TS_RUNTIME=/opt/treesitter \
    HOME=/tmp/home LANG=C.UTF-8 LC_ALL=C.UTF-8 TZ=UTC \
    TERM=xterm-256color COLORTERM=truecolor VHS_NO_SANDBOX=true \
    VHS_HOST=127.0.0.1 VHS_PORT=1976
WORKDIR /tmp
ENTRYPOINT ["python3", "/repo/tests/snapshots/capture.py"]
