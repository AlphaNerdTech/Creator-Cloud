#!/bin/sh
set -eu

BASE="/media/ANT_Files/CreatorCloud"
INGEST_ROOT="$BASE/Library"
LOG_DIR="$BASE/logs"
INDEX_DIR="$BASE/index"
DB_DIR="$INDEX_DIR/db"

LOG_FILE="$LOG_DIR/ingest.log"
SUMMARY_LOG="$LOG_DIR/ingest_summary.log"
HASH_DB="$DB_DIR/file_hashes.sha1"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
HOST="$(hostname 2>/dev/null || echo ZimaBoard2)"
START_TS="$(date +%s)"

mkdir -p "$INGEST_ROOT" "$LOG_DIR" "$INDEX_DIR" "$DB_DIR"
touch "$LOG_FILE" "$SUMMARY_LOG" "$HASH_DB"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"; }

# Decide camera name from folder patterns + filenames
detect_camera() {
  DEV="$1"

  # --- Filename-based detection (best when cards are reused) ---
  find "$DEV/DCIM" -maxdepth 3 -type f 2>/dev/null | grep -qiE '/DJI_.*\.(mp4|mov)$' && { echo "DJI"; return; }
  find "$DEV/DCIM" -maxdepth 3 -type f 2>/dev/null | grep -qiE '/MVI_[0-9]{4}\.(mp4|mov)$' && { echo "Canon"; return; }

  # --- Folder-based detection ---
  [ -d "$DEV/DCIM/100GOPRO" ] && { echo "GoPro"; return; }
  [ -d "$DEV/DCIM/101GOPRO" ] && { echo "GoPro"; return; }
  [ -d "$DEV/MISC/GOPRO" ] && { echo "GoPro"; return; }

  ls "$DEV" 2>/dev/null | grep -qiE '^DJI_' && { echo "DJI"; return; }
  [ -d "$DEV/DCIM/100MEDIA" ] && { echo "DJI"; return; }
  [ -d "$DEV/DCIM" ] && ls "$DEV/DCIM" 2>/dev/null | grep -qiE '^DJI_[0-9]+' && { echo "DJI"; return; }

  [ -d "$DEV/PRIVATE" ] && { echo "Sony"; return; }
  [ -d "$DEV/DCIM/SONY" ] && { echo "Sony"; return; }

  [ -d "$DEV/DCIM" ] && ls "$DEV/DCIM" 2>/dev/null | grep -qi 'CANON' && { echo "Canon"; return; }

  echo "UnknownCamera"
}

# Copy + sort files into Photos/Videos/Other
# Outputs counters: "PHOTOS VIDEOS OTHER DUP ERR BYTES"
copy_and_sort() {
  SRCROOT="$1"
  DESTBASE="$2"
  INCLUDE_REGEX="${3-}"

  PHOTOS=0; VIDEOS=0; OTHER=0; DUP=0; ERR=0; BYTES=0

  mkdir -p "$DESTBASE/Photos" "$DESTBASE/Videos" "$DESTBASE/Other"

  LIST="/tmp/cc_files_${RUN_ID}.txt"
  rm -f "$LIST"
  find "$SRCROOT" -type f 2>/dev/null > "$LIST" || true

  while IFS= read -r F; do
    [ -n "$F" ] || continue
    BN="$(basename "$F")"

    case "$BN" in
      .DS_Store|Thumbs.db|desktop.ini) continue ;;
    esac

    # Optional include filter
    if [ -n "$INCLUDE_REGEX" ]; then
      echo "$F" | grep -qE "$INCLUDE_REGEX" || continue
    fi

    EXT="$(echo "${BN##*.}" | tr '[:upper:]' '[:lower:]')"
    DESTSUB="Other"
    case "$EXT" in
      jpg|jpeg|heic|png|cr2|cr3|arw|nef|dng|raf) DESTSUB="Photos" ;;
      mp4|mov|m4v|mts|m2ts|insv|lrv|avi|mkv)     DESTSUB="Videos" ;;
    esac

    DESTPATH="$DESTBASE/$DESTSUB/$BN"

    # Hash-based duplicates with self-heal:
    # - If hash exists AND referenced file still exists -> skip
    # - If hash exists BUT file was deleted -> remove stale hash and allow re-ingest
    HASH=""
    if [ -f "$HASH_DB" ]; then
      HASH="$(sha1sum "$F" 2>/dev/null | awk '{print $1}')"
      if [ -n "$HASH" ]; then
        HIT="$(grep "^$HASH " "$HASH_DB" 2>/dev/null | head -n 1 || true)"
        if [ -n "$HIT" ]; then
          OLD_PATH="$(echo "$HIT" | cut -d' ' -f2-)"
          if [ -f "$OLD_PATH" ]; then
            DUP=$((DUP+1))
            continue
          else
            # stale DB entry -> remove it so DB heals
            grep -v "^$HASH " "$HASH_DB" > "${HASH_DB}.tmp" 2>/dev/null || true
            mv "${HASH_DB}.tmp" "$HASH_DB" 2>/dev/null || true
          fi
        fi
      fi
    fi

    if cp -p "$F" "$DESTPATH" 2>>"$LOG_FILE"; then
      case "$DESTSUB" in
        Photos) PHOTOS=$((PHOTOS+1)) ;;
        Videos) VIDEOS=$((VIDEOS+1)) ;;
        Other)  OTHER=$((OTHER+1)) ;;
      esac
      SZ="$(stat -c %s "$DESTPATH" 2>/dev/null || echo 0)"
      BYTES=$((BYTES+SZ))
      [ -n "$HASH" ] && echo "$HASH $DESTPATH" >> "$HASH_DB"
    else
      ERR=$((ERR+1))
    fi
  done < "$LIST"

  rm -f "$LIST" || true
  echo "$PHOTOS $VIDEOS $OTHER $DUP $ERR $BYTES"
}

log "RUN start run_id=$RUN_ID host=$HOST"

for DEV in /media/*; do
  [ -d "$DEV" ] || continue
  NAME="$(basename "$DEV")"

  case "$NAME" in
    ANT_Files|ZimaOS-HD) continue ;;
  esac

  ls "$DEV" >/dev/null 2>&1 || continue

  CAMERA="$(detect_camera "$DEV")"
  DAY="$(date +%F)"
  STAMP="$(date +%H%M%S)"

  DEST_FINAL="$INGEST_ROOT/$CAMERA/$DAY/${NAME}_$STAMP"
  DEST_TMP="$INGEST_ROOT/$CAMERA/$DAY/.tmp_${NAME}_$STAMP.$$"

  mkdir -p "$DEST_TMP"

  log "DETECT mount=$NAME camera=$CAMERA day=$DAY tmp=$DEST_TMP final=$DEST_FINAL"
  log "COPY begin src=$DEV"

  COUNTS="$(copy_and_sort "$DEV" "$DEST_TMP")"

  PHOTOS="$(echo "$COUNTS" | awk '{print $1}')"
  VIDEOS="$(echo "$COUNTS" | awk '{print $2}')"
  OTHER="$(echo "$COUNTS" | awk '{print $3}')"
  DUP="$(echo "$COUNTS" | awk '{print $4}')"
  ERR="$(echo "$COUNTS" | awk '{print $5}')"
  BYTES="$(echo "$COUNTS" | awk '{print $6}')"

  sync

  NOW_TS="$(date +%s)"
  ELAPSED=$((NOW_TS - START_TS))
  COPIED_TOTAL=$((PHOTOS + VIDEOS + OTHER))

  # No empty folders when all dupes / nothing copied
  if [ "$COPIED_TOTAL" -eq 0 ]; then
    rm -rf "$DEST_TMP" 2>/dev/null || true
    log "RUN skip: nothing copied (dup_skipped=$DUP) -> removed temp folder"
  else
    mkdir -p "$(dirname "$DEST_FINAL")"
    mv "$DEST_TMP" "$DEST_FINAL"
    log "RUN commit: copied_total=$COPIED_TOTAL -> $DEST_FINAL"
  fi

  HEALTH="OK"
  [ "$ERR" -gt 0 ] && HEALTH="WARN_ERRORS"
  [ "$COPIED_TOTAL" -eq 0 ] && HEALTH="WARN_ZERO_COPIED"
  [ "$COPIED_TOTAL" -gt 0 ] && [ "$PHOTOS" -eq 0 ] && [ "$VIDEOS" -eq 0 ] && HEALTH="WARN_ONLY_OTHER"
  [ "$DUP" -ge 50 ] && HEALTH="WARN_HIGH_DUPS"

  log "COPY done photos=$PHOTOS videos=$VIDEOS other=$OTHER dup_skipped=$DUP bytes=$BYTES errors=$ERR health=$HEALTH"

  {
    echo "[$(date '+%F %T')] SUMMARY run_id=$RUN_ID mount=$NAME camera=$CAMERA"
    echo "  copied_total=$COPIED_TOTAL photos=$PHOTOS videos=$VIDEOS other=$OTHER"
    echo "  dup_skipped=$DUP bytes=$BYTES errors=$ERR elapsed=${ELAPSED}s"
    echo "  health=$HEALTH"
  } >> "$SUMMARY_LOG"
done

log "RUN end run_id=$RUN_ID elapsed=$(( $(date +%s) - START_TS ))s"
