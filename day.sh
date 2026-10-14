#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
  ROOT_DIR="$(dirname "$SCRIPT_DIR")"
else
  ROOT_DIR="$SCRIPT_DIR"
fi
TEMPLATE_DIR="$ROOT_DIR/assets/templates"
DAYS_DIR="$ROOT_DIR/days"

# Card geometry / style defaults (override via env if needed)
CARD_W="${CARD_W:-210}"
CARD_H="${CARD_H:-254}"
BG_OPACITY="${BG_OPACITY:-40%}"
FONT="${FONT:-C059-Bold}"
MONTH_SIZE="${MONTH_SIZE:-50}"
DAY_SIZE="${DAY_SIZE:-180}"

BACKGROUND="$TEMPLATE_DIR/white.png"
FRAME="$TEMPLATE_DIR/empty-transparent.png"
BASE="$TEMPLATE_DIR/white.png"
SUFFIX=""

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") MONTH DAY [-s SUFFIX] [-f FRAME] [-b BACKGROUND] [-h]

  MONTH            Month label (rendered uppercased, e.g. OKT)
  DAY              Day label (e.g. 11)
  -s SUFFIX        Appended to output as "-SUFFIX" (default: none)
  -f FRAME         Frame overlay image path (default: $TEMPLATE_DIR/empty-transparent.png)
  -b BACKGROUND    Background image path, http(s):// URL, or bare
                   host/path (https by default, http fallback on 404)
  -h               Show this help and exit
EOF
  exit "${1:-1}"
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

[[ "$#" -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]] && usage 0
[[ $# -ge 2 ]] || usage
MONTH="$1"
DAY="$2"
shift 2

while getopts ":s:f:b:h" opt; do
  case "$opt" in
    s) SUFFIX="-$OPTARG" ;;
    f) FRAME="$OPTARG" ;;
    b) BACKGROUND="$OPTARG" ;;
    h) usage 0 ;;
    :) die "option -$OPTARG requires an argument (try -h)" ;;
    \?) die "unknown option -$OPTARG (try -h)" ;;
  esac
done

[[ -n "$MONTH" && -n "$DAY" ]] || die "MONTH and DAY must be non-empty"

need_cmd magick
need_cmd curl

[[ -f "$BASE" ]] || die "base image not found: $BASE"
[[ -f "$FRAME" ]] || die "frame image not found: $FRAME"

mkdir -p "$DAYS_DIR"

# --- temp files with cleanup ---
TMP_FILES=()
cleanup() { rm -f "${TMP_FILES[@]:-}"; }
trap cleanup EXIT

new_tmp() { # new_tmp <suffix> -> echoes path
  local f
  f="$(mktemp --suffix="$1")"
  TMP_FILES+=("$f")
  printf '%s' "$f"
}

# --- resolve BACKGROUND (URL or local file) ---
fetch_url() { # fetch_url <url> <dest> -> 0 on success
  curl -fSLsS "$1" -o "$2"
}

fetch_https_then_http() { # fetch_https_then_http <https-url> <dest>
  local https_url="$1" dest="$2" code http_url
  if fetch_url "$https_url" "$dest"; then
    return 0
  fi
  code="$(curl -s -o /dev/null -w '%{http_code}' -L "$https_url" || true)"
  if [[ "$code" == "404" ]]; then
    http_url="http://${https_url#https://}"
    echo "HTTPS returned 404, retrying over HTTP..." >&2
    fetch_url "$http_url" "$dest" \
      || die "failed to download background: $https_url (HTTP 404, HTTP retry failed)"
  else
    die "failed to download background: $https_url (HTTP ${code:-unknown})"
  fi
}

case "$BACKGROUND" in
  http://*|https://*)
    # Scheme explicitly given: use exactly as specified, no fallback.
    echo "Downloading background..."
    tmp_bg="$(new_tmp ".img")"
    fetch_url "$BACKGROUND" "$tmp_bg" \
      || die "failed to download background: $BACKGROUND"
    BACKGROUND="$tmp_bg"
    ;;
  *://*)
    die "unsupported URL scheme (use http:// or https://): $BACKGROUND"
    ;;
  *)
    if [[ ! -f "$BACKGROUND" && "$BACKGROUND" == *.* ]]; then
      # Bare host/path without scheme: https by default, http fallback on 404.
      echo "Downloading background..."
      tmp_bg="$(new_tmp ".img")"
      fetch_https_then_http "https://$BACKGROUND" "$tmp_bg"
      BACKGROUND="$tmp_bg"
    else
      [[ -f "$BACKGROUND" ]] || die "background image not found: $BACKGROUND"
    fi
    ;;
esac

# 1. Resize + cover + fade background
resized_bg="$(new_tmp ".png")"
magick "$BACKGROUND" \
  -resize "${CARD_W}x${CARD_H}^" \
  -gravity center \
  -extent "${CARD_W}x${CARD_H}" \
  -alpha set -channel A -evaluate set "$BG_OPACITY" \
  "$resized_bg"

# 2. Composite: base -> background -> frame; 3. Annotate month + day
output_name="${MONTH}-${DAY}${SUFFIX}.png"
output_path="$DAYS_DIR/$output_name"

magick "$BASE" \
  "$resized_bg" -gravity center -compose over -composite \
  "$FRAME" -gravity center -compose over -composite \
  -font "$FONT" -fill white -pointsize "$MONTH_SIZE" -gravity center -annotate +0-40 "${MONTH^^}" \
  -fill black -pointsize "$DAY_SIZE" -annotate +0+70 "$DAY" \
  "$output_path"

echo "Generated: $output_path"
