#!/bin/sh
set -eu

# -----------------------------
# Creator Cloud Ingest Watcher (Trust the Automation)
# Polls /media for new mounts and triggers auto_ingest.sh
# -----------------------------

BASE="/media/ANT_Files/CreatorCloud"
LOG_DIR="$BASE/logs"
LOG_FILE="$LOG_DIR/ingest_watch.log"

ENV_FILE="${ENV_FILE:-$BASE/config/ingest.env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

MEDIA_GLOB="${MEDIA_GLOB:-/media/*}"
IGNORE_MOUNTS_REGEX="${IGNORE_MOUNTS_REGEX:-^(ANT_Files|ZimaOS-HD)$}"
POLL_SECONDS="${POLL_SECONDS:-5}"
AUTO_INGEST_PATH="${AUTO_INGEST_PATH:-/media/ANT_Files/CreatorCloud/bin/auto_ingest.sh}"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"; }

# If the script is stored in repo path instead of /cc/bin, fall back:
if [ ! -x "$AUTO_INGEST_PATH" ]; then
  # common repo path
  if [ -x "$BASE/ai/../zima-board-2/ingest/auto_ingest.sh" ]; then
    AUTO_INGEST_PATH="$BASE/ai/../zima-board-2/ingest/auto_ingest.sh"
  fi
fi

log "WATCH start poll=${POLL_SECONDS}s auto_ingest=$AUTO_INGEST_PATH env_file=$ENV_FILE"

SEEN="/tmp/cc_seen_mounts.txt"
: > "$SEEN"

while true; do
  for DEV in $MEDIA_GLOB; do
    [ -d "$DEV" ] || continue
    NAME="$(basename "$DEV")"

    echo "$NAME" | grep -qE "$IGNORE_MOUNTS_REGEX" && continue
    ls "$DEV" >/dev/null 2>&1 || continue

    # Only trigger on things that look like media (reduces false triggers)
    if [ ! -d "$DEV/DCIM" ] && [ ! -d "$DEV/PRIVATE" ] && [ ! -d "$DEV/MISC" ]; then
      continue
    fi

    # Trigger once per mount appearance
    if ! grep -qx "$NAME" "$SEEN" 2>/dev/null; then
      echo "$NAME" >> "$SEEN"
      log "WATCH detected mount=$NAME -> triggering ingest"
      # Run ingest (it has its own locking + processed tracking)
      sh "$AUTO_INGEST_PATH" >> "$LOG_FILE" 2>&1 || log "WATCH ingest returned nonzero for mount=$NAME"
    fi
  done

  # Refresh seen list: remove mounts that are gone, so reinsert triggers next time
  TMP="/tmp/cc_seen_mounts.tmp"
  : > "$TMP"
  while IFS= read -r M; do
    [ -n "$M" ] || continue
    [ -d "/media/$M" ] && echo "$M" >> "$TMP"
  done < "$SEEN" || true
  mv "$TMP" "$SEEN" 2>/dev/null || true

  sleep "$POLL_SECONDS"
done
