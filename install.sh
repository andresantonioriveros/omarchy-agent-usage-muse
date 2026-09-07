#!/bin/bash
# Install the Muse usage collector for Omarchy's Agents panel.
#
# Two modes (default: --user, no privilege needed):
#   --user     Copy the collector to ~/.local/bin and publish its record
#              through a systemd user timer. The panel picks up whatever
#              valid JSON lands in the usage directory, so no system paths
#              are touched.
#   --system   Install into /usr/bin and link into $OMARCHY_PATH/bin so the
#              stock `omarchy-agent-usage-update` runner drives it (sudo).
#              The user timer stands down while a system collector exists.
set -euo pipefail

MODE="user"
WITH_ASSETS=false
UNINSTALL=false
for arg in "$@"; do
  case "$arg" in
    --user) MODE="user" ;;
    --system) MODE="system" ;;
    --with-assets) WITH_ASSETS=true ;;
    --uninstall) UNINSTALL=true ;;
    -h|--help)
      echo "Usage: ./install.sh [--user] [--system] [--with-assets] [--uninstall]"
      echo "  --user (default): sudo-free sidecar timer publishing muse.json."
      echo "  --system: drive the collector through omarchy-agent-usage-update (sudo)."
      echo "  --with-assets: also install the Muse marks (sudo, may reset on updates)."
      echo "  --uninstall: remove timer, copies, system files, and the record."
      exit 0
      ;;
    *) echo "Unknown argument: $arg (see --help)" >&2; exit 1 ;;
  esac
done

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$REPO_DIR/omarchy-agent-usage-muse"
SIDECAR="$REPO_DIR/sidecar.sh"
TARGET="/usr/bin/omarchy-agent-usage-muse"
USER_BIN="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE="omarchy-agent-usage-muse.service"
TIMER="omarchy-agent-usage-muse.timer"
USAGE_RECORD="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage/muse.json"

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
[[ -f $COLLECTOR ]] || { echo "collector not found: $COLLECTOR" >&2; exit 1; }

if [[ $UNINSTALL == "true" ]]; then
  echo "-> disabling user timer"
  systemctl --user disable --now "$TIMER" 2>/dev/null || true
  rm -f "$SYSTEMD_USER_DIR/$SERVICE" "$SYSTEMD_USER_DIR/$TIMER"
  systemctl --user daemon-reload 2>/dev/null || true
  echo "-> removing user copies"
  rm -f "$USER_BIN/omarchy-agent-usage-muse" "$USER_BIN/omarchy-agent-usage-muse-sidecar"
  echo "-> removing system files (sudo)"
  sudo rm -f "$TARGET" "${OMARCHY_PATH:-/usr/share/omarchy}/bin/omarchy-agent-usage-muse" \
    /usr/share/omarchy/shell/plugins/agents/assets/muse.svg \
    /usr/share/omarchy/shell/plugins/agents/assets/muse-light.svg || true
  echo "-> removing usage record"
  rm -f "$USAGE_RECORD"
  echo "ok: uninstalled (sudo step may have been skipped without privileges)"
  exit 0
fi

echo "-> validating collector output"
if ! record="$("$COLLECTOR" --force)" || [[ -z $record ]] || ! jq -e '.id == "muse"' >/dev/null <<<"$record"; then
  echo "collector validation failed" >&2
  exit 1
fi

if [[ $MODE == "system" ]]; then
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

  echo "-> refreshing usage record"
  omarchy agent usage update muse --force
else
  echo "-> installing user copies to $USER_BIN"
  mkdir -p "$USER_BIN"
  install -m755 "$COLLECTOR" "$USER_BIN/omarchy-agent-usage-muse"
  install -m755 "$SIDECAR" "$USER_BIN/omarchy-agent-usage-muse-sidecar"

  echo "-> installing user timer"
  mkdir -p "$SYSTEMD_USER_DIR"
  install -m644 "$REPO_DIR/systemd/$SERVICE" "$REPO_DIR/systemd/$TIMER" "$SYSTEMD_USER_DIR/"
  systemctl --user daemon-reload
  systemctl --user enable --now "$TIMER"

  echo "-> publishing the first record now"
  systemctl --user start "$SERVICE" || true
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

if [[ -s $USAGE_RECORD ]]; then
  echo "ok: open the Agents panel (press 'r' inside it to refresh the stock tabs now)"
else
  echo "warning: no record at $USAGE_RECORD;" >&2
  echo "warning: the panel will not show a Muse tab until a record is published" >&2
  exit 1
fi
