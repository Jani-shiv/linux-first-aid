# linux-first-aid Dockerfile
# Multi-stage build for minimal final image

# Build stage
FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    bash \
    coreutils \
    procps \
    iproute2 \
    util-linux \
    findutils \
    grep \
    sed \
    gawk \
    bc \
    jq \
    curl \
    openssl \
    smartmontools \
    lsof \
    sysstat \
    iotop \
    htop \
    ncurses

WORKDIR /build
COPY . .

RUN make release

# Runtime stage
FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    coreutils \
    procps \
    iproute2 \
    util-linux \
    findutils \
    grep \
    sed \
    gawk \
    bc \
    jq \
    curl \
    openssl \
    smartmontools \
    lsof \
    systemd \
    sysstat

# Create non-root user
RUN addgroup -g 1000 -S firstaid && \
    adduser -u 1000 -S firstaid -G firstaid

# Copy built artifacts
COPY --from=builder /build/build/linux-first-aid-* /tmp/
RUN tar -xzf /tmp/linux-first-aid-*.tar.gz -C /tmp/ && \
    cp /tmp/linux-first-aid-*/bin/first-aid /usr/local/bin/ && \
    cp -r /tmp/linux-first-aid-*/lib /usr/share/linux-first-aid/ && \
    mkdir -p /etc/linux-first-aid && \
    cp /tmp/linux-first-aid-*/config/config.yaml /etc/linux-first-aid/ && \
    rm -rf /tmp/linux-first-aid-*

# Set up directories
RUN mkdir -p /var/lib/linux-first-aid /var/cache/linux-first-aid /var/log/linux-first-aid && \
    chown -R firstaid:firstaid /var/lib/linux-first-aid /var/cache/linux-first-aid /var/log/linux-first-aid

USER firstaid

ENTRYPOINT ["first-aid"]
CMD ["--help"]