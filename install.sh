#!/bin/bash
# Install the Muse usage collector for Omarchy's Agents panel.
set -euo pipefail

WITH_ASSETS=false
for arg in "$@"; do
  case "$arg" in
    --with-assets) WITH_ASSETS=true ;;
    -h|--help)
      echo "Usage: ./install.sh [--with-assets]"
      echo "  Installs omarchy-agent-usage-muse to /usr/bin, links it into"
      echo "  \$OMARCHY_PATH/bin for discovery, and refreshes the usage record."
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

# omarchy-agent-usage-update only discovers collectors in $OMARCHY_PATH/bin,
# where the stock agents are symlinks to /usr/bin. Without this link the
# refresh below exits 0 but silently writes no muse record.
OMARCHY_BIN_DIR="${OMARCHY_PATH:-/usr/share/omarchy}/bin"
if [[ -d $OMARCHY_BIN_DIR ]]; then
  echo "-> linking $OMARCHY_BIN_DIR/omarchy-agent-usage-muse (sudo; may need re-linking after system updates)"
  sudo ln -sf "$TARGET" "$OMARCHY_BIN_DIR/omarchy-agent-usage-muse"
else
  echo "omarchy bin dir not found, skipping link (refresh will write no record): $OMARCHY_BIN_DIR" >&2
fi

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

USAGE_RECORD="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage/muse.json"
if [[ -s $USAGE_RECORD ]]; then
  echo "ok: open the Agents panel (press 'r' inside it to refresh now)"
else
  echo "warning: refresh wrote no record at $USAGE_RECORD;" >&2
  echo "warning: the panel will not show a Muse tab until the collector is discoverable" >&2
  exit 1
fi
