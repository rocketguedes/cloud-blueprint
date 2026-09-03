#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 || "${FORCE_COLOR:-0}" == "1" ]]; then
  RED=$'\033[0;31m'
  YELLOW=$'\033[0;33m'
  GREEN=$'\033[0;32m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' DIM='' RESET=''
fi

info()    { printf "${CYAN}info${RESET} %s\n" "$*"; }
success() { printf "${GREEN}done${RESET} %s\n" "$*"; }
warn()    { printf "${YELLOW}warn${RESET} %s\n" "$*" >&2; }
error()   { printf "${RED}error${RESET}: %s\n" "$*" >&2; }

if [[ -z "${1:-}" ]]; then
  printf '%s\n' \
    "Update a Kustomization's container image to the latest tag and digest." \
    "" \
    "Usage: container-image-update <target>" \
    "" \
    "Arguments:" \
    "  <target>  Path to an app/infrastructure directory or its kustomization.yaml" \
    "" \
    "Examples:" \
    "  container-image-update apps/headlamp" \
    "  container-image-update infrastructure/configs/postgresql" \
    "  container-image-update apps/headlamp/kustomization.yaml" >&2
  exit 1
fi

TARGET="$1"

if [[ -d "$TARGET" ]]; then
  FILE="$TARGET/kustomization.yaml"
else
  FILE="$TARGET"
fi

if [[ ! -f "$FILE" ]]; then
  error "file not found: $FILE"
  exit 1
fi

IMAGE_COUNT=$(yq '.images | length // 0' "$FILE")

if [[ "$IMAGE_COUNT" -eq 0 ]]; then
  exit 0
fi

for ((i = 0; i < IMAGE_COUNT; i++)); do
  image_entry=$(yq ".images[$i]" "$FILE")
  IMAGE=$(yq '.name // ""' <<<"$image_entry")
  CURRENT_TAG=$(yq '.newTag // ""' <<<"$image_entry")
  CURRENT_DIGEST=$(yq '.digest // ""' <<<"$image_entry")

  if [[ -z "$IMAGE" || -z "$CURRENT_TAG" ]]; then
    continue
  fi

  if [[ "$CURRENT_TAG" =~ ^(([a-zA-Z0-9_.-]+-)?[vV]?)([0-9]+(\.[0-9]+)+)(-[a-zA-Z0-9_.-]+)?$ ]]; then
    TAG_PREFIX="${BASH_REMATCH[1]}"
    TAG_SUFFIX="${BASH_REMATCH[5]}"

    ESCAPED_PREFIX="${TAG_PREFIX//./\\.}"
    ESCAPED_SUFFIX="${TAG_SUFFIX//./\\.}"

    REGEX="^${ESCAPED_PREFIX}[0-9]+(\.[0-9]+)+${ESCAPED_SUFFIX}\$"

    LATEST_TAG=$(crane ls "$IMAGE" | grep -E "$REGEX" | sort -V | tail -n 1 || true)

    if [[ -z "$LATEST_TAG" ]]; then
      warn "${BOLD}$IMAGE${RESET}: no matching tags for '${YELLOW}$CURRENT_TAG${RESET}'"
      continue
    fi

    if [[ "$CURRENT_TAG" != "$LATEST_TAG" ]]; then
      info "update available: ${YELLOW}$CURRENT_TAG${RESET} → ${GREEN}$LATEST_TAG${RESET}"
      info "${BOLD}$IMAGE${RESET}: fetching digest for ${GREEN}$LATEST_TAG${RESET}"
      NEW_DIGEST=$(crane digest "${IMAGE}:${LATEST_TAG}")

      IDX=$i LATEST_TAG=$LATEST_TAG NEW_DIGEST=$NEW_DIGEST \
        yq -i '
          .images[env(IDX)].newTag   = env(LATEST_TAG) |
          .images[env(IDX)].digest   = env(NEW_DIGEST)
        ' "$FILE"

      LABEL_VERSION=$(yq '.labels[0].pairs["app.kubernetes.io/version"] // ""' "$FILE")
      if [[ "$LABEL_VERSION" == "$CURRENT_TAG" ]]; then
        LATEST_TAG=$LATEST_TAG \
          yq -i '(.labels[] | select(has("pairs")) | .pairs["app.kubernetes.io/version"]) = env(LATEST_TAG)' "$FILE"
      fi

      success "${BOLD}$IMAGE${RESET}: ${YELLOW}$CURRENT_TAG${RESET} → ${GREEN}$LATEST_TAG${RESET} ${DIM}($NEW_DIGEST)${RESET}"
    else
      if [[ -z "$CURRENT_DIGEST" ]]; then
        info "${BOLD}$IMAGE${RESET}: fetching missing digest"
        NEW_DIGEST=$(crane digest "${IMAGE}:${CURRENT_TAG}")
        IDX=$i NEW_DIGEST=$NEW_DIGEST yq -i '.images[env(IDX)].digest = env(NEW_DIGEST)' "$FILE"
        success "${BOLD}$IMAGE${RESET}: digest pinned ${DIM}($NEW_DIGEST)${RESET}"
      else
        success "${BOLD}$IMAGE${RESET}: already up to date (${GREEN}$CURRENT_TAG${RESET})"
      fi
    fi
  else
    info "${BOLD}$IMAGE${RESET}: skipping mutable tag (${YELLOW}$CURRENT_TAG${RESET})"
  fi
done
