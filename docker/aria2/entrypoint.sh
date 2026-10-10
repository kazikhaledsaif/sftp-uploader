#!/bin/sh
# Starts aria2 for plain HTTP/HTTPS/FTP downloads only (BitTorrent and metalink disabled).
set -e

if [ -z "$ARIA2_RPC_SECRET" ]; then
  echo "ARIA2_RPC_SECRET is not set" >&2
  exit 1
fi

# The session file lets unfinished downloads continue after a restart.
touch /session/aria2.session

exec aria2c \
  --enable-rpc=true \
  --rpc-listen-all=true \
  --rpc-listen-port=6800 \
  --rpc-secret="$ARIA2_RPC_SECRET" \
  --dir=/data/Downloads \
  --input-file=/session/aria2.session \
  --save-session=/session/aria2.session \
  --save-session-interval=10 \
  --auto-save-interval=10 \
  --continue=true \
  --max-concurrent-downloads="${ARIA2_MAX_CONCURRENT:-5}" \
  --max-connection-per-server="${ARIA2_CONNECTIONS:-16}" \
  --split="${ARIA2_CONNECTIONS:-16}" \
  --min-split-size=4M \
  --optimize-concurrent-downloads=true \
  --max-overall-download-limit="${ARIA2_SPEED_LIMIT:-0}" \
  --disk-cache="${ARIA2_DISK_CACHE:-64M}" \
  --file-allocation="${ARIA2_FILE_ALLOCATION:-falloc}" \
  --max-tries=10 \
  --retry-wait=5 \
  --connect-timeout=30 \
  --timeout=60 \
  --lowest-speed-limit=1K \
  --http-accept-gzip=true \
  --async-dns=false \
  --auto-file-renaming=false \
  --allow-overwrite=false \
  --follow-torrent=false \
  --follow-metalink=false \
  --enable-dht=false \
  --enable-dht6=false \
  --bt-enable-lpd=false \
  --enable-peer-exchange=false \
  --console-log-level=warn \
  --summary-interval=0
