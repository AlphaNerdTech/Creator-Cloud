#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="/media/ANT_Files/CreatorCloud/scripts/config.env"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

LOG_DIR="${LOG_DIR:-/media/ANT_Files/CreatorCloud/logs}"
LOG="${LOG:-$LOG_DIR/ingest_watch.log}"
STATE="${STATE:-/tmp/ingest_mounts.state}"

INGEST_SCRIPT_PATH="${INGEST_SCRIPT_PATH:-/media/ANT_Files/CreatorCloud/scripts/auto_ingest.sh}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-30}"
POLL_SECONDS="${POLL_SECONDS:-2}"

mkdir -p "$LOG_DIR"
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

list_mounts() {
  mount | awk '
    $3 ~ "^/media/" {
      if ($3 == "/media/ANT_Files") next
      if ($3 == "/media") next
      if ($3 == "/media/ZimaOS-HD") next
      print $3 " | " $1 " | " $5
    }' | sort
}

list_mounts > "$STATE" 2>/dev/null || true

while true; do
  sleep "$POLL_SECONDS"

  NOW="/tmp/ingest_mounts.now"
  list_mounts > "$NOW" 2>/dev/null || true

  if ! cmp -s "$STATE" "$NOW"; then
    NEW_LIST="$(comm -13 "$STATE" "$NOW" || true)"
    REM_LIST="$(comm -23 "$STATE" "$NOW" || true)"

    [ -n "$NEW_LIST" ] && echo "$NEW_LIST" | sed 's/^/NEW: /' | while read -r L; do log "$L"; done
    [ -n "$REM_LIST" ] && echo "$REM_LIST" | sed 's/^/REMOVED: /' | while read -r L; do log "$L"; done

    if [ -z "$NEW_LIST" ]; then
      log "Mount change detected (no NEW mounts) -> skipping ingest"
      mv "$NOW" "$STATE"
      continue
    fi

    LAST="/tmp/ingest_last_run"
    NOWTS="$(date +%s)"
    LASTTS=0
    [ -f "$LAST" ] && LASTTS="$(cat "$LAST" 2>/dev/null || echo 0)"

    if [ $((NOWTS - LASTTS)) -lt "$COOLDOWN_SECONDS" ]; then
      log "Cooldown active (skipping duplicate trigger)"
      mv "$NOW" "$STATE"
      continue
    fi
    echo "$NOWTS" > "$LAST"

    log "NEW mount detected -> running ingest: $INGEST_SCRIPT_PATH"
    sh "$INGEST_SCRIPT_PATH" || log "Ingest script returned non-zero exit code"

    mv "$NOW" "$STATE"
  else
    rm -f "$NOW" 2>/dev/null || true
  fi
done
