#!/bin/sh
set -eu

# Load config from same folder (preferred) OR from a known path.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="/media/ANT_Files/CreatorCloud/scripts/config.env"

[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

INGEST_ROOT="${INGEST_ROOT:-/media/ANT_Files/CreatorCloud/Library}"
LOG_DIR="${LOG_DIR:-/media/ANT_Files/CreatorCloud/logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/ingest.log}"
SKIP_MOUNTS="${SKIP_MOUNTS:-ANT_Files|Ingest|scripts|ZimaOS-HD}"
DRY_RUN="${DRY_RUN:-false}"

mkdir -p "$INGEST_ROOT" "$LOG_DIR"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"; }

detect_camera() {
  DEV="$1"

  find "$DEV/DCIM" -maxdepth 2 -type f 2>/dev/null | grep -qiE '/DJI_.*\.(mp4|mov)$' && { echo "DJI"; return; }
  find "$DEV/DCIM" -maxdepth 2 -type f 2>/dev/null | grep -qiE '/MVI_[0-9]{4}\.(mp4|mov)$' && { echo "Canon"; return; }

  [ -d "$DEV/DCIM/100GOPRO" ] && { echo "GoPro"; return; }
  [ -d "$DEV/DCIM/101GOPRO" ] && { echo "GoPro"; return; }
  [ -d "$DEV/MISC/GOPRO" ] && { echo "GoPro"; return; }

  ls "$DEV" 2>/dev/null | grep -qiE '^DJI_' && { echo "DJI"; return; }
  [ -d "$DEV/DCIM/100MEDIA" ] && { echo "DJI"; return; }
  [ -d "$DEV/DCIM" ] && ls "$DEV/DCIM" 2>/dev/null | grep -qiE '^DJI_[0-9]+' && { echo "DJI"; return; }

  [ -d "$DEV/PRIVATE" ] && { echo "Sony"; return; }
  [ -d "$DEV/DCIM/SONY" ] && { echo "Sony"; return; }

  ls "$DEV/DCIM" 2>/dev/null | grep -qi 'CANON' && { echo "Canon"; return; }

  echo "UnknownCamera"
}

copy_and_sort() {
  SRCROOT="$1"
  DESTBASE="$2"
  INCLUDE_REGEX="${3-}"

  mkdir -p "$DESTBASE/Photos" "$DESTBASE/Videos" "$DESTBASE/Other"

  find "$SRCROOT" -type f 2>/dev/null | while read -r F; do
    BN="$(basename "$F")"
    case "$BN" in .DS_Store|Thumbs.db|desktop.ini) continue ;; esac

    if [ -n "$INCLUDE_REGEX" ]; then
      echo "$F" | grep -qiE "$INCLUDE_REGEX" || continue
    fi

    EXT="$(echo "${BN##*.}" | tr '[:upper:]' '[:lower:]')"

    if [ "$DRY_RUN" = "true" ]; then
      log "DRYRUN: would copy $F"
      continue
    fi

    case "$EXT" in
      jpg|jpeg|heic|png|cr2|cr3|arw|nef|dng|raf)
        cp -p "$F" "$DESTBASE/Photos/" 2>>"$LOG_FILE" || true
        ;;
      mp4|mov|m4v|mts|m2ts|insv|lrv|avi|mkv)
        cp -p "$F" "$DESTBASE/Videos/" 2>>"$LOG_FILE" || true
        ;;
      *)
        cp -p "$F" "$DESTBASE/Other/" 2>>"$LOG_FILE" || true
        ;;
    esac
  done
}

log "Ingest run started"

for DEV in /media/*; do
  [ -d "$DEV" ] || continue
  NAME="$(basename "$DEV")"

  echo "$NAME" | grep -qiE "^($SKIP_MOUNTS)$" && continue
  ls "$DEV" >/dev/null 2>&1 || continue

  DAY="$(date +%F)"
  STAMP="$(date +%H%M%S)"

  HAS_DJI=0
  HAS_CANON=0

  [ -d "$DEV/DCIM" ] && ls "$DEV/DCIM" 2>/dev/null | grep -qiE '^DJI_[0-9]+' && HAS_DJI=1
  find "$DEV/DCIM" -maxdepth 2 -type f 2>/dev/null | grep -qiE '/DJI_.*\.(mp4|mov)$' && HAS_DJI=1

  [ -d "$DEV/DCIM/100CANON" ] && HAS_CANON=1
  [ -d "$DEV/DCIM/CANONMSC" ] && HAS_CANON=1
  find "$DEV/DCIM" -maxdepth 2 -type f 2>/dev/null | grep -qiE '/MVI_[0-9]{4}\.(mp4|mov)$' && HAS_CANON=1

  if [ "$HAS_DJI" -eq 0 ] && [ "$HAS_CANON" -eq 0 ]; then
    CAMERA="$(detect_camera "$DEV")"
    DEST="$INGEST_ROOT/$CAMERA/$DAY/${NAME}_$STAMP"
    mkdir -p "$DEST"
    log "Detected mount=$NAME camera=$CAMERA -> $DEST"
    copy_and_sort "$DEV" "$DEST"
    sync || true
    log "Completed $NAME ($CAMERA)"
    continue
  fi

  if [ "$HAS_DJI" -eq 1 ]; then
    CAMERA="DJI"
    DEST="$INGEST_ROOT/$CAMERA/$DAY/${NAME}_$STAMP"
    mkdir -p "$DEST"
    log "Detected mount=$NAME camera=$CAMERA -> $DEST"
    DJI_FILTER='/DCIM/DJI_[0-9]+/|/DJI_.*\.(mp4|mov)$'
    copy_and_sort "$DEV" "$DEST" "$DJI_FILTER"
    sync || true
    log "Completed $NAME ($CAMERA)"
  fi

  if [ "$HAS_CANON" -eq 1 ]; then
    CAMERA="Canon"
    DEST="$INGEST_ROOT/$CAMERA/$DAY/${NAME}_$STAMP"
    mkdir -p "$DEST"
    log "Detected mount=$NAME camera=$CAMERA -> $DEST"
    CANON_FILTER='/DCIM/100CANON/|/DCIM/CANONMSC/|/MVI_[0-9]{4}\.(mp4|mov)$'
    copy_and_sort "$DEV" "$DEST" "$CANON_FILTER"
    sync || true
    log "Completed $NAME ($CAMERA)"
  fi
done

log "Ingest run finished"
