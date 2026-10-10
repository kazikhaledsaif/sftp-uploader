# Small aria2 image built from Debian's package (no third-party images).
FROM debian:trixie-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends aria2 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/aria2-entrypoint.sh
RUN chmod +x /usr/local/bin/aria2-entrypoint.sh

VOLUME ["/session"]
EXPOSE 6800

ENTRYPOINT ["/usr/local/bin/aria2-entrypoint.sh"]
