#!/bin/bash
# Install the Muse usage collector for Omarchy's Agents panel.
set -euo pipefail

WITH_ASSETS=false
for arg in "$@"; do
  case "$arg" in
    --with-assets) WITH_ASSETS=true ;;
    -h|--help)
      echo "Usage: ./install.sh [--with-assets]"
      echo "  Installs omarchy-agent-usage-muse to /usr/bin and refreshes the usage record."
      echo "  --with-assets also installs the Muse marks into the Agents plugin assets."
      exit 0
      ;;
    *) echo "Unknown argument: $arg (see --help)" >&2; exit 1 ;;
  esac
done

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$REPO_DIR/omarchy-agent-usage-muse"
TARGET="/usr/bin/omarchy-agent-usage-muse"

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
[[ -f $COLLECTOR ]] || { echo "collector not found: $COLLECTOR" >&2; exit 1; }

echo "-> validating collector output"
if ! record="$("$COLLECTOR" --force)" || [[ -z $record ]] || ! jq -e '.id == "muse"' >/dev/null <<<"$record"; then
  echo "collector validation failed" >&2
  exit 1
fi

echo "-> installing $TARGET (sudo)"
sudo install -m755 "$COLLECTOR" "$TARGET"

if [[ $WITH_ASSETS == "true" ]]; then
  ASSETS_DIR="/usr/share/omarchy/shell/plugins/agents/assets"
  if [[ -d $ASSETS_DIR ]]; then
    echo "-> installing assets to $ASSETS_DIR (sudo; may be reset by system updates)"
    sudo install -m644 "$REPO_DIR/assets/muse.svg" "$REPO_DIR/assets/muse-light.svg" "$ASSETS_DIR/"
  else
    echo "assets dir not found, skipping: $ASSETS_DIR" >&2
  fi
fi

echo "-> refreshing usage record"
omarchy agent usage update muse --force

echo "ok: open the Agents panel (press 'r' inside it to refresh now)"
