#!/usr/bin/env bash
set -euo pipefail

# Creator Cloud - Safe Public Ingest Script
# Copies (or optionally moves) media from a mounted card to a structured destination.
# Uses an external config file (config.env). Never commit your real config.env.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
EXAMPLE_FILE="${SCRIPT_DIR}/config.example.env"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "❌ Missing config.env"
  echo "➡️  Copy ${EXAMPLE_FILE} to ${CONFIG_FILE} and edit it."
  exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

# -------- Defaults (safe) --------
DEST_ROOT="${DEST_ROOT:-/mnt/storage/CreatorCloud}"
PROJECT_NAME="${PROJECT_NAME:-CreatorCloud}"
CAMERA_NAME="${CAMERA_NAME:-CameraA}"
DATE_FORMAT="${DATE_FORMAT:-%Y-%m-%d}"

COPY_MODE="${COPY_MODE:-copy}"          # copy | move
VERIFY_MODE="${VERIFY_MODE:-basic}"     # off | basic
DRY_RUN="${DRY_RUN:-false}"

SOURCE_SUBDIR="${SOURCE_SUBDIR:-}"
INCLUDE_EXT="${INCLUDE_EXT:-MP4,MOV,JPG,JPEG,PNG,WAV}"
EXCLUDE_DIRS="${EXCLUDE_DIRS:-MISC,PRIVATE,.*}"

LOG_DIR="${LOG_DIR:-${DEST_ROOT}/_logs}"
mkdir -p "${LOG_DIR}"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(timestamp)] $*" | tee -a "${LOG_DIR}/ingest.log"; }

# -------- Helpers --------
to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

# Build include extension matcher for find
# e.g. "MP4,MOV" -> \( -iname "*.mp4" -o -iname "*.mov" \)
build_ext_find_args() {
  local ext_csv="$1"
  IFS=',' read -r -a exts <<< "${ext_csv}"
  local args=()
  for e in "${exts[@]}"; do
    e="$(echo "$e" | xargs)"
    [[ -z "$e" ]] && continue
    args+=(-iname "*.$(to_lower "$e")" -o -iname "*.$(echo "$e" | tr '[:lower:]' '[:upper:]')")
  done
  # Remove last -o by printing as-is and trimming not worth it; find tolerates it in grouped expr usage.
  echo "${args[@]}"
}

is_mounted_dir() {
  local p="$1"
  mount | awk '{print $3}' | grep -qx "$p"
}

# -------- Inputs --------
CARD_MOUNT="${1:-}"
if [[ -z "${CARD_MOUNT}" ]]; then
  echo "Usage: ./auto_ingest.sh /path/to/mounted/card"
  echo "Example: ./auto_ingest.sh /mnt/card"
  exit 1
fi

if [[ ! -d "${CARD_MOUNT}" ]]; then
  echo "❌ Card path not found: ${CARD_MOUNT}"
  exit 1
fi

# Optional: warn if it's not a mount point (still allow for testing)
if ! is_mounted_dir "${CARD_MOUNT}"; then
  log "⚠️  ${CARD_MOUNT} does not appear to be a mount point. Continuing (useful for testing)."
fi

SOURCE_PATH="${CARD_MOUNT}"
if [[ -n "${SOURCE_SUBDIR}" ]]; then
  SOURCE_PATH="${CARD_MOUNT}/${SOURCE_SUBDIR}"
fi

if [[ ! -d "${SOURCE_PATH}" ]]; then
  echo "❌ Source subdir not found: ${SOURCE_PATH}"
  exit 1
fi

DATE_FOLDER="$(date +"${DATE_FORMAT}")"
DEST_PATH="${DEST_ROOT}/${PROJECT_NAME}/${DATE_FOLDER}/${CAMERA_NAME}"

mkdir -p "${DEST_PATH}"
log "✅ Ingest starting"
log "Source: ${SOURCE_PATH}"
log "Dest:   ${DEST_PATH}"
log "Mode:   ${COPY_MODE} | Verify: ${VERIFY_MODE} | DryRun: ${DRY_RUN}"

# Build find args
EXT_ARGS="$(build_ext_find_args "${INCLUDE_EXT}")"

# Exclude directories
# We'll prune directories matching EXCLUDE_DIRS
IFS=',' read -r -a excl <<< "${EXCLUDE_DIRS}"

# Collect files
log "🔎 Scanning for media files..."
mapfile -t files < <(
  cd "${SOURCE_PATH}" && \
  find . \
    $(for d in "${excl[@]}"; do d="$(echo "$d" | xargs)"; [[ -z "$d" ]] && continue; echo "-path \"./$d\" -prune -o"; done) \
    -type f \( ${EXT_ARGS} \) -print | sed 's|^\./||'
)

if [[ "${#files[@]}" -eq 0 ]]; then
  log "ℹ️  No matching media files found. Nothing to do."
  exit 0
fi

log "📦 Found ${#files[@]} files."

copy_one() {
  local rel="$1"
  local src="${SOURCE_PATH}/${rel}"
  local dst="${DEST_PATH}/${rel}"
  mkdir -p "$(dirname "${dst}")"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "DRYRUN: would ${COPY_MODE} '${src}' -> '${dst}'"
    return 0
  fi

  if [[ "${COPY_MODE}" == "move" ]]; then
    cp -p "${src}" "${dst}"
    rm -f "${src}"
  else
    cp -p "${src}" "${dst}"
  fi

  if [[ "${VERIFY_MODE}" == "basic" ]]; then
    local s1 s2
    s1=$(stat -c%s "${src}" 2>/dev/null || true)
    s2=$(stat -c%s "${dst}" 2>/dev/null || true)
    # If move mode, src might be gone; skip verify based on src size then
    if [[ "${COPY_MODE}" == "copy" ]]; then
      if [[ "${s1}" != "${s2}" ]]; then
        log "❌ Verify failed (size mismatch): ${rel}"
        return 1
      fi
    fi
  fi

  log "✅ ${rel}"
}

# Copy loop
fail=0
for f in "${files[@]}"; do
  if ! copy_one "${f}"; then
    fail=1
  fi
done

if [[ "${fail}" -eq 1 ]]; then
  log "⚠️  Ingest completed with errors. Check the log: ${LOG_DIR}/ingest.log"
  exit 2
fi

log "🎉 Ingest complete."
